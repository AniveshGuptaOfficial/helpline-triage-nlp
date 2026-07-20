"""
Phase 1 — Load and relabel medical_triage_500.jsonl

What this does:
1. Downloads the correct JSONL file (NOT the csv, which is missing urgency/risk fields)
2. Flattens the nested JSON structure into a flat table
3. Maps urgency_category (immediate/urgent/routine) onto our project categories
   (Emergency / Medicine Query) — Appointment is handled separately in Phase 2
4. Saves a clean CSV that every later phase will reuse
"""

import json
import os
import urllib.request
import pandas as pd

RAW_DIR = "data/raw"
PROCESSED_DIR = "data/processed"
RAW_FILE = os.path.join(RAW_DIR, "medical_triage_500.jsonl")
OUTPUT_FILE = os.path.join(PROCESSED_DIR, "labeled_triage.csv")

DATASET_URL = (
    "https://huggingface.co/datasets/syntech-ai/medical-triage-500"
    "/resolve/main/medical_triage_500.jsonl"
)


def download_dataset():
    """Download the jsonl file if we don't already have a local copy."""
    os.makedirs(RAW_DIR, exist_ok=True)
    if os.path.exists(RAW_FILE):
        print(f"Found existing file at {RAW_FILE}, skipping download.")
        return
    print(f"Downloading dataset from {DATASET_URL} ...")
    urllib.request.urlretrieve(DATASET_URL, RAW_FILE)
    print(f"Saved to {RAW_FILE}")


def load_jsonl(path):
    """Load a jsonl file into a list of dicts."""
    records = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records


def flatten_record(rec):
    """Flatten one nested record into a flat dict of the fields we need."""
    patient = rec.get("patient", {})
    presentation = rec.get("presentation", {})
    risk = rec.get("risk_assessment", {})
    triage = rec.get("triage_classification", {})

    return {
        "case_id": rec.get("case_id"),
        "age": patient.get("age"),
        "gender": patient.get("gender"),
        "symptoms": presentation.get("symptoms"),
        "duration": presentation.get("duration"),
        "onset": presentation.get("onset"),
        "context": presentation.get("context"),
        "risk_level": risk.get("risk_level"),
        "red_flags": ", ".join(risk.get("red_flags", []) or []),
        "urgency_category": triage.get("urgency_category"),
        "urgency_reasoning": triage.get("urgency_reasoning"),
        "safety_notice": rec.get("safety_notice"),
    }


def map_project_category(urgency_category):
    """
    Map the dataset's 3-tier urgency into our 2 of the 3 project categories.
    Appointment isn't present in this dataset at all — that's built separately.

        immediate -> Emergency
        urgent    -> Medicine Query   (borderline but not life-threatening)
        routine   -> Medicine Query
    """
    if urgency_category == "immediate":
        return "Emergency"
    elif urgency_category in ("urgent", "routine"):
        return "Medicine Query"
    else:
        return "Unknown"  # flags anything unexpected instead of hiding it


def main():
    download_dataset()

    print("Loading and flattening records...")
    raw_records = load_jsonl(RAW_FILE)
    flat_records = [flatten_record(r) for r in raw_records]
    df = pd.DataFrame(flat_records)

    print(f"Loaded {len(df)} records.")

    df["category"] = df["urgency_category"].apply(map_project_category)

    unknown_count = (df["category"] == "Unknown").sum()
    if unknown_count > 0:
        print(f"WARNING: {unknown_count} records had an unrecognized "
              f"urgency_category value — check these manually.")

    print("\nCategory distribution:")
    print(df["category"].value_counts())

    print("\nOriginal urgency_category distribution (for reference):")
    print(df["urgency_category"].value_counts())

    os.makedirs(PROCESSED_DIR, exist_ok=True)
    df.to_csv(OUTPUT_FILE, index=False)
    print(f"\nSaved cleaned dataset to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()