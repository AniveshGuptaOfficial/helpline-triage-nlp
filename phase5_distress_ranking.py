"""
Phase 5 - Sentiment/distress scoring and priority ranking (Emergency-only)

What this does:
1. Loads the labeled triage data from Phase 1, filters to Emergency-category
   queries only (this layer is never applied to Medicine Query or Appointment)
2. Runs each Emergency query through j-hartmann/emotion-english-distilroberta-base,
   a 7-emotion classifier (anger, disgust, fear, joy, neutral, sadness, surprise)
3. Extracts the "fear" score as the distress signal (this is the model swap we
   made from the original generic-sentiment pick, since fear detection maps
   much more directly onto "how distressed does this emergency sound")
4. Ranks Emergency queries by distress score, highest first - this ranking is
   what determines priority order in the final pipeline, NOT a reclassification
5. Saves the ranked result for use in later phases (GPT prompting, Flask API)

Note: this does not touch Medicine Query or Appointment queries at all - the
distress layer is strictly an Emergency-only refinement, per the original
problem statement.
"""

import os
import pandas as pd
from transformers import pipeline

TRIAGE_FILE = "data/processed/labeled_triage.csv"
OUTPUT_FILE = "data/processed/emergency_priority_ranked.csv"

MODEL_NAME = "j-hartmann/emotion-english-distilroberta-base"


def extract_fear_score(emotion_scores):
    """emotion_scores is a list of {'label': ..., 'score': ...} dicts.
    Order isn't guaranteed, so we match by label explicitly rather than
    assuming position."""
    for item in emotion_scores:
        if item["label"] == "fear":
            return item["score"]
    return None  # shouldn't happen with this model, but fail loud if it does


def main():
    print(f"Loading triage data from {TRIAGE_FILE} ...")
    df = pd.read_csv(TRIAGE_FILE)

    emergency_df = df[df["category"] == "Emergency"].copy().reset_index(drop=True)
    print(f"Total records: {len(df)}, Emergency-only: {len(emergency_df)}")

    print(f"\nLoading emotion classifier ({MODEL_NAME}) ...")
    emotion_classifier = pipeline(
        "text-classification", model=MODEL_NAME, top_k=None
    )

    print("Scoring distress (fear) for each Emergency query...")
    texts = emergency_df["text"].tolist()

    batch_size = 16
    all_scores = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i : i + batch_size]
        results = emotion_classifier(batch)
        all_scores.extend(results)
        print(f"  Scored {min(i + batch_size, len(texts))}/{len(texts)}")

    emergency_df["distress_score"] = [extract_fear_score(r) for r in all_scores]

    emergency_df = emergency_df.sort_values(
        "distress_score", ascending=False
    ).reset_index(drop=True)
    emergency_df["priority_rank"] = emergency_df.index + 1

    print("\nTop 10 highest-priority (most distressed) Emergency queries:")
    print(
        emergency_df[["priority_rank", "distress_score", "text"]]
        .head(10)
        .to_string(index=False)
    )

    print("\nBottom 10 lowest-priority Emergency queries (still Emergency, just calmer wording):")
    print(
        emergency_df[["priority_rank", "distress_score", "text"]]
        .tail(10)
        .to_string(index=False)
    )

    print(f"\nDistress score stats:\n{emergency_df['distress_score'].describe()}")

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    emergency_df.to_csv(OUTPUT_FILE, index=False)
    print(f"\nSaved ranked Emergency queries to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
