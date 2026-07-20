"""
Phase 3 - Merge all three categories and train the baseline classifier

What this does:
1. Loads Phase 1's output (labeled_triage.csv) and Phase 2's output
   (appointment_queries.csv), unifying them into one text+category dataset
2. Saves that combined dataset (Phase 4's transformer classifier will reuse it)
3. Splits into train/test sets (stratified, so each category is proportionally
   represented in both splits)
4. Trains a baseline pipeline: TF-IDF vectorizer + Logistic Regression
5. Reports accuracy, precision, recall, F1 per category (Emergency recall is
   the metric we care about most, per the evaluation plan)
6. Saves the trained pipeline so later phases can reuse or compare against it
"""

import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, confusion_matrix
import joblib

PROCESSED_DIR = "data/processed"
TRIAGE_FILE = os.path.join(PROCESSED_DIR, "labeled_triage.csv")
APPOINTMENT_FILE = os.path.join(PROCESSED_DIR, "appointment_queries.csv")
COMBINED_FILE = os.path.join(PROCESSED_DIR, "combined_dataset.csv")

MODEL_DIR = "models"
MODEL_FILE = os.path.join(MODEL_DIR, "baseline_classifier.joblib")


def load_and_merge():
    """Combine triage (symptoms/category) and appointment (text/category)
    into one unified text/category dataset."""
    triage_df = pd.read_csv(TRIAGE_FILE)
    appointment_df = pd.read_csv(APPOINTMENT_FILE)

    triage_unified = triage_df[["symptoms", "category"]].rename(
        columns={"symptoms": "text"}
    )
    appointment_unified = appointment_df[["text", "category"]]

    combined = pd.concat([triage_unified, appointment_unified], ignore_index=True)
    combined = combined.dropna(subset=["text", "category"]).reset_index(drop=True)

    return combined


def main():
    print("Merging datasets...")
    df = load_and_merge()

    os.makedirs(PROCESSED_DIR, exist_ok=True)
    df.to_csv(COMBINED_FILE, index=False)
    print(f"Combined dataset saved to {COMBINED_FILE}")

    print(f"\nTotal records: {len(df)}")
    print("\nCategory distribution:")
    print(df["category"].value_counts())

    X = df["text"]
    y = df["category"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"\nTrain size: {len(X_train)}, Test size: {len(X_test)}")

    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=2, max_features=5000)),
        ("clf", LogisticRegression(max_iter=1000, class_weight="balanced")),
    ])

    print("\nTraining baseline classifier (TF-IDF + Logistic Regression)...")
    pipeline.fit(X_train, y_train)

    y_pred = pipeline.predict(X_test)

    print("\nClassification report (test set):")
    print(classification_report(y_test, y_pred))

    print("Confusion matrix (rows = actual, columns = predicted):")
    labels = sorted(y.unique())
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    cm_df = pd.DataFrame(cm, index=labels, columns=labels)
    print(cm_df)

    os.makedirs(MODEL_DIR, exist_ok=True)
    joblib.dump(pipeline, MODEL_FILE)
    print(f"\nSaved trained baseline model to {MODEL_FILE}")


if __name__ == "__main__":
    main()
