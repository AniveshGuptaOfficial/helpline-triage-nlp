"""
Phase 7 - Flask API: the full pipeline behind one endpoint

What this does:
Wraps everything built in Phases 1-6 behind a single HTTP endpoint:

  POST /predict   { "query": "..." }
       -> classifies into Emergency / Medicine Query / Appointment
       -> if Emergency: scores distress (fear) via the emotion model
       -> generates a category-specific response via Gemini
       -> returns one JSON object with everything the Flutter app needs

All models are loaded ONCE at startup (not per-request) - loading a
transformer on every request would make each call take several seconds
instead of a fraction of a second.

Note on priority ranking: Phase 5's ranking was a batch operation (rank
these 230 known Emergency queries against each other). A live API only
sees one query at a time, so there's nothing to rank it against yet - we
return the raw distress_score here. A real deployment would feed this
score into a live queue that ranks currently-waiting Emergency queries
against each other; that queueing layer is a natural future extension,
not built in this phase.
"""

import os
import json
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import torch
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

print("Loading intent classifier...")
classifier_tokenizer = DistilBertTokenizerFast.from_pretrained(CLASSIFIER_DIR)
classifier_model = DistilBertForSequenceClassification.from_pretrained(CLASSIFIER_DIR)
classifier_model.eval()

with open(os.path.join(CLASSIFIER_DIR, "label_mapping.json")) as f:
    LABEL_MAPPING = {int(k): v for k, v in json.load(f).items()}

print("Loading emotion/distress model...")
emotion_classifier = pipeline("text-classification", model=EMOTION_MODEL_NAME, top_k=None)

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
        "audience. Do NOT provide a definitive diagnosis or specific drug "
        "dosages. Always end your response with a clear disclaimer recommending "
        "they consult a doctor for a proper diagnosis and treatment plan."
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

def classify_query(text):
    inputs = classifier_tokenizer(
        text, truncation=True, padding=True, max_length=128, return_tensors="pt"
    )
    with torch.no_grad():
        logits = classifier_model(**inputs).logits
    predicted_id = int(torch.argmax(logits, dim=1).item())
    return LABEL_MAPPING[predicted_id]


def score_distress(text):
    scores = emotion_classifier(text)[0]  # single input -> list of {label, score}
    for item in scores:
        if item["label"] == "fear":
            return float(item["score"])
    return None


def generate_response(category, text, distress_score=None):
    system_prompt = SYSTEM_PROMPTS[category]
    if category == "Emergency" and distress_score is not None:
        user_message = f"Query: {text}\nDistress score: {distress_score:.3f}"
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

    category = classify_query(query_text)

    distress_score = None
    escalation_flag = False
    if category == "Emergency":
        distress_score = score_distress(query_text)
        escalation_flag = True

    try:
        gpt_response = generate_response(category, query_text, distress_score)
    except Exception as e:
        gpt_response = None
        gpt_error = str(e)
    else:
        gpt_error = None

    result = {
        "query": query_text,
        "category": category,
        "escalation_flag": escalation_flag,
        "distress_score": distress_score,
        "response": gpt_response,
    }
    if gpt_error:
        result["gpt_error"] = gpt_error

    return jsonify(result)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
