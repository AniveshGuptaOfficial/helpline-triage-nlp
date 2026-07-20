"""
Phase 4 - Fine-tune a transformer classifier (DistilBERT)

What this does:
1. Loads the combined dataset from Phase 3 (data/processed/combined_dataset.csv)
2. Encodes the 3 category labels numerically, saves the mapping for later phases
3. Splits into train/test (same stratified approach as Phase 3, for a fair comparison)
4. Tokenizes text using the DistilBERT tokenizer
5. Fine-tunes distilbert-base-uncased for 3-way classification
6. Evaluates on the held-out test set: accuracy, precision, recall, F1 per
   category, and a confusion matrix - directly comparable to Phase 3's baseline
7. Saves the fine-tuned model + tokenizer + label mapping for later phases

Note: this will be noticeably slower than Phase 3, since it's training a real
neural network instead of a simple linear model. On a CPU-only machine (no
NVIDIA GPU), expect roughly 10-25 minutes total for 3 epochs on ~635 records.
That's normal - let it run.
"""

import os
import json
import numpy as np
import pandas as pd
import torch
from torch.utils.data import Dataset
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix
from transformers import (
    DistilBertTokenizerFast,
    DistilBertForSequenceClassification,
    TrainingArguments,
    Trainer,
)

COMBINED_FILE = "data/processed/combined_dataset.csv"
MODEL_DIR = "models/transformer_classifier"
LABEL_MAP_FILE = os.path.join(MODEL_DIR, "label_mapping.json")

MODEL_NAME = "distilbert-base-uncased"
MAX_LENGTH = 128
NUM_EPOCHS = 3
BATCH_SIZE = 8


class TextDataset(Dataset):
    """Wraps tokenized encodings + labels for the Trainer API."""

    def __init__(self, encodings, labels):
        self.encodings = encodings
        self.labels = labels

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        item = {k: torch.tensor(v[idx]) for k, v in self.encodings.items()}
        item["labels"] = torch.tensor(self.labels[idx])
        return item


def compute_metrics(eval_pred):
    logits, labels = eval_pred
    preds = np.argmax(logits, axis=1)
    report = classification_report(labels, preds, output_dict=True, zero_division=0)
    return {
        "accuracy": report["accuracy"],
        "macro_f1": report["macro avg"]["f1-score"],
    }


def main():
    print(f"Loading combined dataset from {COMBINED_FILE} ...")
    df = pd.read_csv(COMBINED_FILE).dropna(subset=["text", "category"])
    print(f"Total records: {len(df)}")
    print(df["category"].value_counts())

    label_encoder = LabelEncoder()
    df["label"] = label_encoder.fit_transform(df["category"])
    label_mapping = {int(i): c for i, c in enumerate(label_encoder.classes_)}
    print(f"\nLabel mapping: {label_mapping}")

    X_train, X_test, y_train, y_test = train_test_split(
        df["text"].tolist(),
        df["label"].tolist(),
        test_size=0.2,
        random_state=42,
        stratify=df["label"],
    )
    print(f"Train size: {len(X_train)}, Test size: {len(X_test)}")

    print(f"\nLoading tokenizer and model ({MODEL_NAME}) ...")
    tokenizer = DistilBertTokenizerFast.from_pretrained(MODEL_NAME)
    model = DistilBertForSequenceClassification.from_pretrained(
        MODEL_NAME, num_labels=len(label_mapping)
    )

    train_encodings = tokenizer(
        X_train, truncation=True, padding=True, max_length=MAX_LENGTH
    )
    test_encodings = tokenizer(
        X_test, truncation=True, padding=True, max_length=MAX_LENGTH
    )

    train_dataset = TextDataset(train_encodings, y_train)
    test_dataset = TextDataset(test_encodings, y_test)

    training_args = TrainingArguments(
        output_dir="models/transformer_checkpoints",
        num_train_epochs=NUM_EPOCHS,
        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=BATCH_SIZE,
        eval_strategy="epoch",
        save_strategy="no",
        logging_steps=20,
        report_to=[],
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=test_dataset,
        compute_metrics=compute_metrics,
    )

    print("\nStarting fine-tuning...")
    trainer.train()

    print("\nEvaluating on test set...")
    predictions = trainer.predict(test_dataset)
    y_pred = np.argmax(predictions.predictions, axis=1)

    label_names = [label_mapping[i] for i in range(len(label_mapping))]

    print("\nClassification report (test set):")
    print(classification_report(y_test, y_pred, target_names=label_names))

    print("Confusion matrix (rows = actual, columns = predicted):")
    cm = confusion_matrix(y_test, y_pred)
    cm_df = pd.DataFrame(cm, index=label_names, columns=label_names)
    print(cm_df)

    os.makedirs(MODEL_DIR, exist_ok=True)
    model.save_pretrained(MODEL_DIR)
    tokenizer.save_pretrained(MODEL_DIR)
    with open(LABEL_MAP_FILE, "w") as f:
        json.dump(label_mapping, f, indent=2)

    print(f"\nSaved fine-tuned model, tokenizer, and label mapping to {MODEL_DIR}")


if __name__ == "__main__":
    main()
