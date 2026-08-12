import json
import os
import urllib.request
import pandas as pd

RAW_DIR = "data/raw"
PROCESSED_DIR = "data/processed"
RAW_FILE = os.path.join(RAW_DIR, "medical_medicine_dataset.jsonl")
OUTPUT_FILE = os.path.join(PROCESSED_DIR, "medicine_dataset.csv")

DATASET_URL = (
    "https://huggingface.co/datasets/darkknight25/medical_medicine_dataset"
    "/resolve/main/medical_medicine_dataset.jsonl?download=true"
)

def download_dataset():
    os.makedirs(RAW_DIR, exist_ok=True)
    if os.path.exists(RAW_FILE):
        os.remove(RAW_FILE)
    req = urllib.request.Request(
        DATASET_URL,
        headers={"User-Agent": "Mozilla/5.0"}
    )
    with urllib.request.urlopen(req) as response, open(RAW_FILE, "wb") as out_file:
        out_file.write(response.read())

def load_jsonl(path):
    records = []
    if not os.path.exists(path):
        return records
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return records

def create_fallback_dataset():
    return [
        {
            "id": 1,
            "medicine_name": "Paracetamol",
            "description": "Common pain reliever and fever reducer.",
            "uses": ["fever", "headache", "mild pain", "body ache"],
            "side_effects": ["nausea", "allergic reactions"],
            "disclaimer": "Consult a doctor for exact dosage."
        },
        {
            "id": 2,
            "medicine_name": "Cetirizine",
            "description": "Antihistamine used to treat allergy symptoms.",
            "uses": ["allergy", "runny nose", "sneezing", "itching"],
            "side_effects": ["drowsiness", "dry mouth"],
            "disclaimer": "May cause drowsiness."
        },
        {
            "id": 3,
            "medicine_name": "Amoxicillin",
            "description": "Antibiotic used to treat bacterial infections.",
            "uses": ["bacterial infection", "cough", "throat infection"],
            "side_effects": ["diarrhea", "rash"],
            "disclaimer": "Requires prescription from a certified medical practitioner."
        },
        {
            "id": 4,
            "medicine_name": "ORSL / Oral Rehydration Salts",
            "description": "Electrolyte balance solution for dehydration.",
            "uses": ["dehydration", "vomiting", "diarrhea", "weakness"],
            "side_effects": ["none"],
            "disclaimer": "Use clean drinking water to prepare."
        },
        {
            "id": 5,
            "medicine_name": "Pantoprazole",
            "description": "Proton pump inhibitor for acidity and heart burn.",
            "uses": ["acidity", "stomach pain", "heartburn", "indigestion"],
            "side_effects": ["headache", "flatulence"],
            "disclaimer": "Take before meals as advised by physician."
        }
    ]

def main():
    try:
        download_dataset()
        records = load_jsonl(RAW_FILE)
    except Exception:
        records = []

    if not records:
        records = create_fallback_dataset()

    rows = []
    for rec in records:
        uses = rec.get("uses", [])
        if isinstance(uses, str):
            uses = [uses]
        side_effects = rec.get("side_effects", [])
        if isinstance(side_effects, str):
            side_effects = [side_effects]

        rows.append({
            "id": rec.get("id"),
            "medicine_name": rec.get("medicine_name"),
            "description": rec.get("description"),
            "uses": json.dumps(uses),
            "side_effects": json.dumps(side_effects),
            "disclaimer": rec.get("disclaimer"),
        })

    df = pd.DataFrame(rows)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    df.to_csv(OUTPUT_FILE, index=False)

if __name__ == "__main__":
    main()