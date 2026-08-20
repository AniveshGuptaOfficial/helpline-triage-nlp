"""
Phase 7 - Flask API: the full pipeline behind one endpoint

Pipeline per request:
  1. Translate to English (classifier/distress model are English-only)
  2. Classify into Emergency / Medicine Query / Appointment
  3. If Emergency: score distress (fear)
  4. If Medicine Query: retrieve relevant real medicines from the
     darkknight25/medical_medicine_dataset (grounds the answer instead of
     relying purely on the LLM's own general knowledge)
  5. Generate a category-specific response via Gemini

All models/data are loaded ONCE at startup, not per-request.
"""

import os
import json
import math
import requests as http_requests
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import torch
import pandas as pd
from transformers import (
    DistilBertTokenizerFast,
    DistilBertForSequenceClassification,
    pipeline,
)
from google import genai
from google.genai import types

load_dotenv()

app = Flask(__name__)

# ---------------------------------------------------------------------
# Load everything ONCE at startup
# ---------------------------------------------------------------------

CLASSIFIER_DIR = "models/transformer_classifier"
EMOTION_MODEL_NAME = "j-hartmann/emotion-english-distilroberta-base"
GPT_MODEL_NAME = "gemini-flash-lite-latest"
MEDICINE_DATASET_FILE = "data/processed/medicine_dataset.csv"

# Phase 10 - Hospital lookup (Emergency / Appointment only)
# Uses OpenStreetMap's Overpass API: free, no API key required. Ratings are
# not reliably available from OSM, so `rating` may be None for many results -
# this is called out explicitly rather than faked. Swap in the Google Places
# Nearby Search API here later if a billed key becomes available; it returns
# real ratings and the rest of this pipeline (sort/display/booking) does not
# need to change.
OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
# Overpass instances reject requests with generic/default User-Agent headers
# (returns 406 Not Acceptable) - a descriptive UA is required.
OVERPASS_HEADERS = {
    "User-Agent": "VaidyumHelplineTriage/1.0 (BCSE409L course project)"
}
HOSPITAL_SEARCH_RADIUS_MILES = 8  # ~13 km, per spec
CATEGORIES_WITH_HOSPITAL_LOOKUP = {"Emergency", "Appointment"}

print("Loading intent classifier...")
classifier_tokenizer = DistilBertTokenizerFast.from_pretrained(CLASSIFIER_DIR)
classifier_model = DistilBertForSequenceClassification.from_pretrained(CLASSIFIER_DIR)
classifier_model.eval()

with open(os.path.join(CLASSIFIER_DIR, "label_mapping.json")) as f:
    LABEL_MAPPING = {int(k): v for k, v in json.load(f).items()}

print("Loading emotion/distress model...")
emotion_classifier = pipeline("text-classification", model=EMOTION_MODEL_NAME, top_k=None)

print("Loading medicine recommendation dataset...")
_medicine_df = pd.read_csv(MEDICINE_DATASET_FILE)
MEDICINE_RECORDS = []
for _, row in _medicine_df.iterrows():
    MEDICINE_RECORDS.append({
        "medicine_name": row["medicine_name"],
        "description": row["description"],
        "uses": json.loads(row["uses"]),
        "side_effects": json.loads(row["side_effects"]),
        "disclaimer": row["disclaimer"],
    })
print(f"Loaded {len(MEDICINE_RECORDS)} medicine records.")

print("Setting up Gemini client...")
gemini_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

SYSTEM_PROMPTS = {
    "Emergency": (
        "You are a triage assistant for a rural healthcare helpline. The user's "
        "message has already been classified as a medical EMERGENCY. Your job "
        "is NOT to diagnose. Respond with: (1) a clear escalation flag telling "
        "the person to seek immediate in-person or emergency medical help, "
        "(2) one or two safe, general first-aid-style actions they can take "
        "right now while help is arriving (nothing invasive or drug-specific), "
        "and (3) a short acknowledgement of urgency. Keep it brief, calm, and "
        "directive. Do not speculate on a specific diagnosis."
    ),
    "Medicine Query": (
        "You are a helpful assistant for a rural healthcare helpline, answering "
        "a general medicine/symptom question. Give a clear, informative, "
        "general-purpose answer in plain language suitable for a non-medical "
        "audience. If reference medicine information is provided below and is "
        "genuinely relevant to the query, you may mention those medicine names "
        "as commonly used options - but do NOT provide specific dosages, do "
        "NOT present it as a definitive diagnosis, and do NOT treat the "
        "reference list as exhaustive. Always end your response with a clear "
        "disclaimer recommending they consult a doctor or pharmacist before "
        "taking any medicine."
    ),
    "Appointment": (
        "You are a scheduling assistant for a rural healthcare helpline. The "
        "user wants to book, reschedule, cancel, or ask about an appointment "
        "or clinic timing. Respond helpfully and confirm the key details you'd "
        "need to proceed (department, preferred day/time), in a friendly, "
        "concise tone. This is a demo response - you don't have access to a "
        "real booking system, so make clear next steps sound plausible without "
        "inventing specific confirmed booking details."
    ),
}

print("All models loaded. Ready to serve requests.")


# ---------------------------------------------------------------------
# Pipeline logic
# ---------------------------------------------------------------------

def translate_to_english(text):
    try:
        response = gemini_client.models.generate_content(
            model=GPT_MODEL_NAME,
            contents=text,
            config=types.GenerateContentConfig(
                system_instruction=(
                    "You are a translation engine. Translate the user's message "
                    "to English. Respond with ONLY the English translation and "
                    "nothing else - no notes, no quotation marks, no explanation. "
                    "If the message is already in English, return it exactly "
                    "unchanged."
                ),
                max_output_tokens=200,
                temperature=0,
            ),
        )
        translated = response.text.strip()
        return translated if translated else text
    except Exception:
        return text


def classify_query(text):
    inputs = classifier_tokenizer(
        text, truncation=True, padding=True, max_length=128, return_tensors="pt"
    )
    with torch.no_grad():
        logits = classifier_model(**inputs).logits
        probs = torch.softmax(logits, dim=1)
    predicted_id = int(torch.argmax(logits, dim=1).item())
    confidence = float(probs[0][predicted_id].item())
    return LABEL_MAPPING[predicted_id], confidence


def score_distress(text):
    scores = emotion_classifier(text)[0]
    for item in scores:
        if item["label"] == "fear":
            return float(item["score"])
    return None


def find_relevant_medicines(query_text_english, top_k=3):
    query_lower = query_text_english.lower()
    scored = []
    for rec in MEDICINE_RECORDS:
        score = 0
        for use in rec.get("uses", []):
            if use.lower() in query_lower:
                score += 1
        if rec.get("medicine_name", "").lower() in query_lower:
            score += 2
        if score > 0:
            scored.append((score, rec))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [rec for _, rec in scored[:top_k]]


def build_medicine_context(matches):
    if not matches:
        return None
    lines = [
        "Reference medicine information (use only if genuinely relevant to "
        "the query; do not treat this as an exhaustive or prescriptive list):"
    ]
    for m in matches:
        lines.append(
            f"- {m['medicine_name']}: {m['description']} "
            f"Commonly used for: {', '.join(m['uses'])}."
        )
    return "\n".join(lines)


def haversine_miles(lat1, lon1, lat2, lon2):
    """Great-circle distance between two lat/lon points, in miles."""
    radius_miles = 3958.8
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return 2 * radius_miles * math.asin(math.sqrt(a))


def find_nearby_hospitals(lat, lon, radius_miles=HOSPITAL_SEARCH_RADIUS_MILES, limit=15):
    """Query OpenStreetMap (Overpass API) for hospitals within radius_miles
    of (lat, lon), sorted by shortest distance first, then highest rating
    (hospitals with no rating data sort after rated ones at the same
    distance tier)."""
    radius_m = int(radius_miles * 1609.34)
    query = f"""
    [out:json][timeout:15];
    (
      node["amenity"="hospital"](around:{radius_m},{lat},{lon});
      way["amenity"="hospital"](around:{radius_m},{lat},{lon});
    );
    out center tags;
    """
    try:
        resp = None
        last_error = None
        for url in OVERPASS_URLS:
            try:
                resp = http_requests.post(
                    url, data={"data": query}, headers=OVERPASS_HEADERS, timeout=15
                )
                resp.raise_for_status()
                break
            except Exception as e:
                last_error = e
                resp = None
                continue
        if resp is None:
            print(f"[hospital search] all Overpass mirrors failed: {last_error}")
            return []
        elements = resp.json().get("elements", [])
    except Exception as e:
        print(f"[hospital search] unexpected error: {e}")
        return []

    hospitals = []
    for el in elements:
        tags = el.get("tags", {})
        name = tags.get("name")
        if not name:
            continue

        if el.get("type") == "node":
            h_lat, h_lon = el.get("lat"), el.get("lon")
        else:
            center = el.get("center") or {}
            h_lat, h_lon = center.get("lat"), center.get("lon")
        if h_lat is None or h_lon is None:
            continue

        distance_miles = haversine_miles(lat, lon, h_lat, h_lon)
        if distance_miles > radius_miles:
            continue

        address_parts = [
            tags.get("addr:housenumber", ""),
            tags.get("addr:street", ""),
            tags.get("addr:city", ""),
            tags.get("addr:state", ""),
            tags.get("addr:postcode", ""),
        ]
        address = ", ".join(p for p in address_parts if p) or "Address not available"

        rating = None
        raw_rating = tags.get("rating") or tags.get("stars")
        if raw_rating:
            try:
                rating = float(raw_rating)
            except ValueError:
                rating = None

        hospitals.append({
            "name": name,
            "lat": float(h_lat),
            "lon": float(h_lon),
            "distance_miles": round(distance_miles, 2),
            "rating": rating,
            "address": address,
        })

    # Primary sort: shortest distance. Secondary sort: highest rating
    # (unrated hospitals treated as lowest so they sort after rated ones
    # at a comparable distance).
    hospitals.sort(key=lambda h: (h["distance_miles"], -(h["rating"] or 0)))
    return hospitals[:limit]


NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"


def reverse_geocode_address(lat, lon):
    """Fallback address lookup via Nominatim, used only when a selected
    hospital's OSM tags didn't include a usable address. Nominatim's usage
    policy caps free reverse-geocoding at roughly 1 request/sec, so this is
    only called once, at booking-confirmation time - never for the whole
    hospital list."""
    try:
        resp = http_requests.get(
            NOMINATIM_REVERSE_URL,
            params={"lat": lat, "lon": lon, "format": "json"},
            headers=OVERPASS_HEADERS,  # same descriptive UA the OSM ecosystem expects
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        return data.get("display_name")
    except Exception as e:
        print(f"[reverse geocode] failed: {e}")
        return None


def build_booking_payload(hospital_name, hospital_address, hospital_lat, hospital_lon,
                           category, appointment_time=None):
    """Builds the confirmation text + map/navigation links for a selected
    hospital. Does not call the LLM - hospital identity, address, and
    coordinates must come straight from the search result, never be
    generated/paraphrased, to avoid ever inventing a wrong address for an
    emergency."""
    if category == "Emergency":
        confirmation_text = f"Emergency slot secured at {hospital_name}."
    else:
        when = appointment_time or "your requested time"
        confirmation_text = f"Appointment confirmation at {hospital_name} for {when}."

    resolved_address = hospital_address
    if not resolved_address or resolved_address == "Address not available":
        resolved_address = reverse_geocode_address(hospital_lat, hospital_lon)
    if not resolved_address:
        resolved_address = "Address not available"

    # `intent:` / geo navigation URL for Android to jump straight into
    # turn-by-turn navigation in the Google Maps app if installed.
    maps_intent_url = f"google.navigation:q={hospital_lat},{hospital_lon}&mode=d"
    # Plain web fallback (works in any browser, or if Maps isn't installed).
    maps_web_url = (
        f"https://www.google.com/maps/dir/?api=1&destination={hospital_lat},{hospital_lon}"
    )
    static_map_url = (
        "https://staticmap.openstreetmap.de/staticmap.php"
        f"?center={hospital_lat},{hospital_lon}&zoom=14&size=600x300"
        f"&maptype=mapnik&markers={hospital_lat},{hospital_lon},red-pushpin"
    )

    return {
        "confirmation_text": confirmation_text,
        "hospital_name": hospital_name,
        "hospital_address": resolved_address,
        "hospital_lat": hospital_lat,
        "hospital_lon": hospital_lon,
        "maps_intent_url": maps_intent_url,
        "maps_web_url": maps_web_url,
        "static_map_url": static_map_url,
    }


def generate_response(category, text, distress_score=None, medicine_context=None):
    system_prompt = SYSTEM_PROMPTS[category]

    if category == "Emergency" and distress_score is not None:
        user_message = f"Query: {text}\nDistress score: {distress_score:.3f}"
    elif category == "Medicine Query" and medicine_context:
        user_message = f"Query: {text}\n\n{medicine_context}"
    else:
        user_message = f"Query: {text}"

    response = gemini_client.models.generate_content(
        model=GPT_MODEL_NAME,
        contents=user_message,
        config=types.GenerateContentConfig(
            system_instruction=system_prompt,
            max_output_tokens=500,
            temperature=0.4,
        ),
    )
    return response.text


# ---------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json(silent=True)
    if not data or "query" not in data:
        return jsonify({"error": "Request body must be JSON with a 'query' field"}), 400

    query_text = data["query"].strip()
    if not query_text:
        return jsonify({"error": "'query' cannot be empty"}), 400

    english_text = translate_to_english(query_text)
    category, confidence = classify_query(english_text)

    distress_score = None
    escalation_flag = False
    medicine_context = None
    if category == "Emergency":
        distress_score = score_distress(english_text)
        escalation_flag = True
    elif category == "Medicine Query":
        matches = find_relevant_medicines(english_text)
        medicine_context = build_medicine_context(matches)

    try:
        gpt_response = generate_response(category, query_text, distress_score, medicine_context)
    except Exception as e:
        gpt_response = None
        gpt_error = str(e)
    else:
        gpt_error = None

    result = {
        "query": query_text,
        "category": category,
        "confidence": confidence,
        "escalation_flag": escalation_flag,
        "distress_score": distress_score,
        "response": gpt_response,
        "hospital_lookup_required": category in CATEGORIES_WITH_HOSPITAL_LOOKUP,
    }
    if gpt_error:
        result["gpt_error"] = gpt_error

    return jsonify(result)


@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json(silent=True)
    if not data or "message" not in data:
        return jsonify({"error": "Request body must be JSON with a 'message' field"}), 400

    message = data["message"].strip()
    if not message:
        return jsonify({"error": "'message' cannot be empty"}), 400

    history = data.get("history", [])
    category = data.get("category")

    is_first_message = not history or category is None

    distress_score = None
    confidence = None
    medicine_context = None
    if is_first_message:
        english_message = translate_to_english(message)
        category, confidence = classify_query(english_message)
        if category == "Emergency":
            distress_score = score_distress(english_message)
        elif category == "Medicine Query":
            matches = find_relevant_medicines(english_message)
            medicine_context = build_medicine_context(matches)
    escalation_flag = category == "Emergency"

    system_prompt = SYSTEM_PROMPTS[category]

    contents = [
        types.Content(role=turn["role"], parts=[types.Part(text=turn["text"])])
        for turn in history
    ]
    message_for_model = message
    if medicine_context:
        message_for_model = f"{message}\n\n{medicine_context}"
    contents.append(types.Content(role="user", parts=[types.Part(text=message_for_model)]))

    try:
        response = gemini_client.models.generate_content(
            model=GPT_MODEL_NAME,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                max_output_tokens=500,
                temperature=0.4,
            ),
        )
        reply_text = response.text
        gpt_error = None
    except Exception as e:
        reply_text = None
        gpt_error = str(e)

    new_history = history + [
        {"role": "user", "text": message},
        {"role": "model", "text": reply_text or ""},
    ]

    result = {
        "category": category,
        "confidence": confidence,
        "distress_score": distress_score,
        "escalation_flag": escalation_flag,
        "response": reply_text,
        "history": new_history,
        "hospital_lookup_required": category in CATEGORIES_WITH_HOSPITAL_LOOKUP,
    }
    if gpt_error:
        result["gpt_error"] = gpt_error

    return jsonify(result)


@app.route("/hospitals", methods=["POST"])
def hospitals():
    """Phase 10 - nearby hospital search.
    Expects JSON: {"latitude": <float>, "longitude": <float>, "radius_miles": <float, optional>}
    Returns hospitals within radius_miles, sorted by shortest distance then
    highest rating.
    """
    data = request.get_json(silent=True)
    if not data or "latitude" not in data or "longitude" not in data:
        return jsonify({"error": "Request body must include 'latitude' and 'longitude'"}), 400

    try:
        lat = float(data["latitude"])
        lon = float(data["longitude"])
    except (TypeError, ValueError):
        return jsonify({"error": "'latitude' and 'longitude' must be numbers"}), 400

    try:
        radius_miles = float(data.get("radius_miles", HOSPITAL_SEARCH_RADIUS_MILES))
    except (TypeError, ValueError):
        radius_miles = HOSPITAL_SEARCH_RADIUS_MILES

    results = find_nearby_hospitals(lat, lon, radius_miles=radius_miles)
    return jsonify({
        "hospitals": results,
        "count": len(results),
        "radius_miles": radius_miles,
    })


@app.route("/book_hospital", methods=["POST"])
def book_hospital():
    """Phase 10 - confirms a hospital selection for an Emergency or
    Appointment request. This is deterministic (no LLM call): hospital
    name/address/coordinates are echoed straight back from what the client
    already fetched via /hospitals, so nothing about the hospital's identity
    is ever generated or guessed.
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400

    hospital_name = data.get("hospital_name")
    hospital_lat = data.get("hospital_lat")
    hospital_lon = data.get("hospital_lon")
    if not hospital_name or hospital_lat is None or hospital_lon is None:
        return jsonify({
            "error": "'hospital_name', 'hospital_lat', and 'hospital_lon' are required"
        }), 400

    payload = build_booking_payload(
        hospital_name=hospital_name,
        hospital_address=data.get("hospital_address"),
        hospital_lat=hospital_lat,
        hospital_lon=hospital_lon,
        category=data.get("category", "Emergency"),
        appointment_time=data.get("appointment_time"),
    )
    return jsonify(payload)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)