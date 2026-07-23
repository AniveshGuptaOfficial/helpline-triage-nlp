"""
Phase 9 - Mixed-urgency batch test: routed pipeline vs. non-routed baseline

What this does:
1. Assembles a mixed batch of real queries: 2 Emergency (one high-distress,
   one low-distress, from Phase 5's ranked output), 2 Medicine Query, and
   2 Appointment queries, all pulled from the actual project datasets.
2. ROUTED: sends each query to the live Flask API (/predict) - the real,
   full pipeline: classify -> distress score (Emergency only) -> category-
   specific GPT prompt.
3. NON-ROUTED BASELINE: sends each query to Gemini directly with ONE single
   generic system prompt, the same for every query regardless of category -
   simulating a naive helpline bot with no routing/triage at all.
4. Compares both on:
     - Does the response explicitly escalate real Emergency queries?
       (keyword check: "911"/"emergency"/"immediately"/similar)
     - Response latency (routed pipeline includes classifier + distress
       model inference time in addition to the GPT call itself)
     - Qualitative differences (printed side by side for manual reading)

Requires: the Flask server (app.py) must already be running on
http://127.0.0.1:5000 before running this script.
"""

import os
import time
import json
import requests
import pandas as pd
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()

FLASK_URL = "http://127.0.0.1:5000/predict"
GEMINI_MODEL = "gemini-flash-lite-latest"
SECONDS_BETWEEN_CALLS = 8

gemini_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

BASELINE_SYSTEM_PROMPT = (
    "You are a general assistant for a healthcare helpline. Answer the "
    "user's message as helpfully as you can."
)

ESCALATION_KEYWORDS = [
    "911", "emergency", "immediately", "urgent", "call for help",
    "seek help now", "call emergency services",
]


def contains_escalation_language(text):
    if not text:
        return False
    lowered = text.lower()
    return any(kw in lowered for kw in ESCALATION_KEYWORDS)


def build_batch():
    """Assemble a fixed, reproducible mixed batch from the real datasets."""
    emergency_df = pd.read_csv("data/processed/emergency_priority_ranked.csv")
    combined_df = pd.read_csv("data/processed/combined_dataset.csv")

    batch = []

    top = emergency_df.iloc[0]
    bottom = emergency_df.iloc[-1]
    batch.append({"true_category": "Emergency", "priority": "high-distress", "text": top["text"]})
    batch.append({"true_category": "Emergency", "priority": "low-distress", "text": bottom["text"]})

    med_samples = (
        combined_df[combined_df["category"] == "Medicine Query"]["text"]
        .sample(2, random_state=11)
        .tolist()
    )
    appt_samples = (
        combined_df[combined_df["category"] == "Appointment"]["text"]
        .sample(2, random_state=11)
        .tolist()
    )
    for t in med_samples:
        batch.append({"true_category": "Medicine Query", "priority": "-", "text": t})
    for t in appt_samples:
        batch.append({"true_category": "Appointment", "priority": "-", "text": t})

    return batch


def call_routed(text, max_retries=2):
    for attempt in range(max_retries + 1):
        try:
            start = time.time()
            res = requests.post(FLASK_URL, json={"query": text}, timeout=30)
            latency = time.time() - start
            data = res.json()
            return {
                "category": data.get("category"),
                "escalation_flag": data.get("escalation_flag"),
                "distress_score": data.get("distress_score"),
                "response": data.get("response"),
                "latency_sec": latency,
            }
        except Exception as e:
            if attempt < max_retries:
                time.sleep(5)
                continue
            return {"category": None, "escalation_flag": None, "distress_score": None,
                     "response": f"[ROUTED CALL FAILED: {e}]", "latency_sec": None}


def call_baseline(text, max_retries=2):
    for attempt in range(max_retries + 1):
        try:
            start = time.time()
            response = gemini_client.models.generate_content(
                model=GEMINI_MODEL,
                contents=f"Query: {text}",
                config=types.GenerateContentConfig(
                    system_instruction=BASELINE_SYSTEM_PROMPT,
                    max_output_tokens=500,
                    temperature=0.4,
                ),
            )
            latency = time.time() - start
            return {"response": response.text, "latency_sec": latency}
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                if attempt < max_retries:
                    print("  Rate limit hit, waiting 60s before retry...")
                    time.sleep(60)
                    continue
            return {"response": f"[BASELINE CALL FAILED: {e}]", "latency_sec": None}


def main():
    batch = build_batch()
    print(f"Built a mixed batch of {len(batch)} queries "
          f"({sum(1 for b in batch if b['true_category']=='Emergency')} Emergency, "
          f"{sum(1 for b in batch if b['true_category']=='Medicine Query')} Medicine Query, "
          f"{sum(1 for b in batch if b['true_category']=='Appointment')} Appointment)")

    results = []
    for i, item in enumerate(batch):
        print(f"\n{'='*70}")
        print(f"[{i+1}/{len(batch)}] True category: {item['true_category']} "
              f"({item['priority']})")
        print(f"Query: {item['text']}")
        print('='*70)

        print("-> Calling ROUTED pipeline (Flask API)...")
        routed = call_routed(item["text"])
        time.sleep(SECONDS_BETWEEN_CALLS)

        print("-> Calling NON-ROUTED baseline (generic Gemini prompt)...")
        baseline = call_baseline(item["text"])
        time.sleep(SECONDS_BETWEEN_CALLS)

        routed_escalates = contains_escalation_language(routed["response"])
        baseline_escalates = contains_escalation_language(baseline["response"])

        routed_latency_str = f"{routed['latency_sec']:.2f}s" if routed['latency_sec'] else "N/A"
        baseline_latency_str = f"{baseline['latency_sec']:.2f}s" if baseline['latency_sec'] else "N/A"

        print(f"\nROUTED   -> category={routed['category']}, "
              f"escalation_flag={routed['escalation_flag']}, "
              f"distress={routed['distress_score']}, "
              f"contains_escalation_language={routed_escalates}, "
              f"latency={routed_latency_str}")
        print(f"ROUTED response: {routed['response']}")
        print()
        print(f"BASELINE -> contains_escalation_language={baseline_escalates}, "
              f"latency={baseline_latency_str}")
        print(f"BASELINE response: {baseline['response']}")

        results.append({
            "true_category": item["true_category"],
            "priority": item["priority"],
            "query": item["text"],
            "routed_category": routed["category"],
            "routed_escalation_flag": routed["escalation_flag"],
            "routed_distress_score": routed["distress_score"],
            "routed_contains_escalation_language": routed_escalates,
            "routed_latency_sec": routed["latency_sec"],
            "baseline_contains_escalation_language": baseline_escalates,
            "baseline_latency_sec": baseline["latency_sec"],
        })

    df = pd.DataFrame(results)
    os.makedirs("data/processed", exist_ok=True)
    df.to_csv("data/processed/phase9_evaluation_results.csv", index=False)

    print(f"\n\n{'='*70}")
    print("SUMMARY")
    print('='*70)
    print(df[[
        "true_category", "priority", "routed_category",
        "routed_contains_escalation_language", "baseline_contains_escalation_language",
        "routed_latency_sec", "baseline_latency_sec",
    ]].to_string(index=False))

    emergency_rows = df[df["true_category"] == "Emergency"]
    print(f"\nOf {len(emergency_rows)} real Emergency queries:")
    print(f"  Routed pipeline used explicit escalation language: "
          f"{emergency_rows['routed_contains_escalation_language'].sum()}/{len(emergency_rows)}")
    print(f"  Non-routed baseline used explicit escalation language: "
          f"{emergency_rows['baseline_contains_escalation_language'].sum()}/{len(emergency_rows)}")

    print(f"\nSaved full results to data/processed/phase9_evaluation_results.csv")


if __name__ == "__main__":
    main()
