"""
Phase 6 - Category-specific GPT prompting (Gemini 2.5 Flash, free tier)

What this does:
Defines three distinct prompting strategies for the GPT-QA module, one per
category, and tests them against a handful of real sample queries pulled from
the datasets built in earlier phases:

  Emergency       -> escalation-focused response, informed by priority_rank
                     from Phase 5. Explicitly avoids confident autonomous
                     diagnosis (per the reliability caution from the
                     literature review) - it flags and guides toward human
                     care, it doesn't try to "diagnose."
  Medicine Query  -> informative, general-purpose answer + a mandatory
                     doctor-consult disclaimer.
  Appointment     -> scheduling-oriented response (confirms details, since
                     this demo isn't wired to a real booking system yet).

Uses Gemini 2.5 Flash via Google AI Studio's free tier. Includes automatic
retry with a 60s backoff if the free-tier rate limit (5 requests/minute) is
hit, since a fixed per-call delay alone isn't always enough against the
rolling window.
"""

import os
import time
import random
import pandas as pd
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

MODEL_NAME = "gemini-flash-lite-latest"
SECONDS_BETWEEN_CALLS = 8

SYSTEM_PROMPTS = {
    "Emergency": (
        "You are a triage assistant for a rural healthcare helpline. The user's "
        "message has already been classified as a medical EMERGENCY and given a "
        "priority rank based on distress signals. Your job is NOT to diagnose. "
        "Respond with: (1) a clear escalation flag telling the person to seek "
        "immediate in-person or emergency medical help, (2) one or two safe, "
        "general first-aid-style actions they can take right now while help is "
        "arriving (nothing invasive or drug-specific), and (3) a short "
        "acknowledgement of urgency appropriate to their priority rank. Keep it "
        "brief, calm, and directive. Do not speculate on a specific diagnosis."
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


def build_user_message(category, query_text, priority_rank=None, distress_score=None):
    """Adds priority context for Emergency queries only."""
    if category == "Emergency" and priority_rank is not None:
        return (
            f"Query: {query_text}\n"
            f"Priority rank: {priority_rank} (1 = most urgent among current "
            f"emergency queries)\nDistress score: {distress_score:.3f}"
        )
    return f"Query: {query_text}"


def get_gpt_response(category, query_text, priority_rank=None, distress_score=None, max_retries=2):
    system_prompt = SYSTEM_PROMPTS[category]
    user_message = build_user_message(category, query_text, priority_rank, distress_score)

    for attempt in range(max_retries + 1):
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=user_message,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    max_output_tokens=500,
                    temperature=0.4,
                ),
            )
            result = response.text
            time.sleep(SECONDS_BETWEEN_CALLS)
            return result
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                if attempt < max_retries:
                    print(f"  Rate limit hit, waiting 60s before retry "
                          f"({attempt + 1}/{max_retries})...")
                    time.sleep(60)
                    continue
                else:
                    return f"[CALL FAILED after retries: rate limit]"
            else:
                return f"[CALL FAILED: {e}]"


def main():
    random.seed(7)

    emergency_df = pd.read_csv("data/processed/emergency_priority_ranked.csv")
    combined_df = pd.read_csv("data/processed/combined_dataset.csv")

    medicine_samples = (
        combined_df[combined_df["category"] == "Medicine Query"]["text"]
        .sample(2, random_state=7)
        .tolist()
    )
    appointment_samples = (
        combined_df[combined_df["category"] == "Appointment"]["text"]
        .sample(2, random_state=7)
        .tolist()
    )
    emergency_high = emergency_df.head(2)
    emergency_low = emergency_df.tail(2)

    print("=" * 70)
    print("EMERGENCY - HIGH PRIORITY")
    print("=" * 70)
    for _, row in emergency_high.iterrows():
        print(f"\n--- Query (priority {row['priority_rank']}, distress "
              f"{row['distress_score']:.3f}): {row['symptoms']} ---")
        reply = get_gpt_response(
            "Emergency", row["symptoms"], row["priority_rank"], row["distress_score"]
        )
        print(reply)

    print("\n" + "=" * 70)
    print("EMERGENCY - LOW PRIORITY (still Emergency category)")
    print("=" * 70)
    for _, row in emergency_low.iterrows():
        print(f"\n--- Query (priority {row['priority_rank']}, distress "
              f"{row['distress_score']:.3f}): {row['symptoms']} ---")
        reply = get_gpt_response(
            "Emergency", row["symptoms"], row["priority_rank"], row["distress_score"]
        )
        print(reply)

    print("\n" + "=" * 70)
    print("MEDICINE QUERY")
    print("=" * 70)
    for query in medicine_samples:
        print(f"\n--- Query: {query} ---")
        reply = get_gpt_response("Medicine Query", query)
        print(reply)

    print("\n" + "=" * 70)
    print("APPOINTMENT")
    print("=" * 70)
    for query in appointment_samples:
        print(f"\n--- Query: {query} ---")
        reply = get_gpt_response("Appointment", query)
        print(reply)


if __name__ == "__main__":
    main()
