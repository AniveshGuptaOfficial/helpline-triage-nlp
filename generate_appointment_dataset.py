"""
Generate the Appointment category dataset (build step 2/5: dataset prep)

Why this exists:
Neither medical-triage-500 nor ai-medical-chatbot cover Appointment/scheduling
queries at all. A small real seed set exists at arghims/Doctor-Appointment-Chatbot
(book_appointment / cancel_appointment intents), but it's too small on its own
(typical Rasa seed-example scale, ~15-30 phrasings). This script expands that
same intent space into ~130 varied, helpline-style queries by combining
realistic sub-intents (book, reschedule, cancel, check availability, ask
timings) with varied phrasing patterns and rural-helpline context.

Output format matches Phase 1's schema convention: a "text" column (the query
itself) and a "category" column, so Phase 3 can simply concatenate this with
the triage data.
"""

import os
import random
import pandas as pd

OUTPUT_DIR = "data/processed"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "appointment_queries.csv")

random.seed(42)

TEMPLATES = {
    "book": [
        "I want to book an appointment with the {dept}",
        "Can I get an appointment for {dept} this {day}?",
        "How do I book a slot with the {dept} doctor?",
        "I need to see the {dept} doctor, how do I book?",
        "Please book me an appointment for {dept} on {day}",
        "Can you schedule a visit to the {dept} for me?",
        "I would like to fix an appointment with {dept}",
        "Is it possible to book {dept} appointment for {time}?",
        "How can I register for the {dept} clinic on {day}?",
        "I want to consult the {dept}, please book a slot",
    ],
    "reschedule": [
        "I need to reschedule my {dept} appointment",
        "Can you move my appointment with {dept} to {day}?",
        "I can't come on {day}, can we change the appointment time?",
        "Please shift my {dept} appointment to {time}",
        "I want to change my appointment date for {dept}",
        "Is it possible to postpone my visit to the {dept}?",
        "My {dept} appointment clashes with something, can it be moved to {day}?",
        "Can we reschedule to next {day} instead?",
    ],
    "cancel": [
        "I want to cancel my appointment with {dept}",
        "Please cancel my {dept} appointment on {day}",
        "I won't be able to come for my {dept} visit, please cancel it",
        "Cancel my booking for {dept}, something came up",
        "How do I cancel an appointment I made for {dept}?",
        "I need to cancel my slot for {day}",
    ],
    "availability": [
        "What are the {dept} doctor's available timings?",
        "Is the {dept} clinic open on {day}?",
        "What time does the {dept} doctor see patients?",
        "Are there any slots available for {dept} this {day}?",
        "When is the next available slot for {dept}?",
        "Does the {dept} doctor work on {day}s?",
        "What are the visiting hours for {dept}?",
        "Is walk-in allowed for {dept} or do I need an appointment?",
    ],
    "camp_or_special": [
        "When is the next vaccination camp in our area?",
        "Is there a health camp scheduled this month?",
        "When is the next eye checkup camp at the clinic?",
        "Is there a free health camp coming up for {day}?",
        "When does the mobile health van visit our village next?",
        "Is there a dental camp scheduled soon?",
    ],
    "follow_up": [
        "I need a follow-up appointment with {dept} after my last visit",
        "Can I get a follow-up slot with the {dept} doctor?",
        "My doctor asked me to come back for a follow-up, how do I book?",
        "I need a review appointment with {dept} next {day}",
    ],
    "general_info": [
        "Do I need to bring my old reports for the {dept} appointment?",
        "How long is the waiting time for {dept} appointments?",
        "Can someone else book an appointment on my behalf for {dept}?",
        "Is home visit available instead of coming to the {dept}?",
        "Can I get an appointment over phone call for {dept}?",
    ],
}

DEPARTMENTS = [
    "general physician", "dentist", "eye specialist", "gynecologist",
    "pediatrician", "orthopedic", "skin specialist", "ENT doctor",
    "diabetes clinic", "vaccination center",
]

DAYS = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    "next week", "tomorrow",
]

TIMES = [
    "morning", "afternoon", "evening", "10 AM", "3 PM", "next available time",
]


def generate_queries(target_count=135):
    generated = set()
    all_templates = []
    for subintent, templates in TEMPLATES.items():
        for t in templates:
            all_templates.append((subintent, t))

    attempts = 0
    max_attempts = target_count * 20

    while len(generated) < target_count and attempts < max_attempts:
        attempts += 1
        subintent, template = random.choice(all_templates)
        text = template.format(
            dept=random.choice(DEPARTMENTS),
            day=random.choice(DAYS),
            time=random.choice(TIMES),
        )
        if text not in {g[1] for g in generated}:
            generated.add((subintent, text))

    return list(generated)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    queries = generate_queries(target_count=135)

    df = pd.DataFrame(queries, columns=["sub_intent", "text"])
    df.insert(0, "case_id", [f"appt_{i+1:04d}" for i in range(len(df))])
    df["category"] = "Appointment"

    print(f"Generated {len(df)} unique appointment queries.")
    print("\nSub-intent distribution:")
    print(df["sub_intent"].value_counts())

    print("\nSample queries:")
    print(df["text"].sample(8, random_state=1).to_string(index=False))

    df.to_csv(OUTPUT_FILE, index=False)
    print(f"\nSaved to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()