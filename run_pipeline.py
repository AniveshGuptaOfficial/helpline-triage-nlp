"""
run_pipeline.py - Runs the full data preparation + training pipeline in order

This does NOT replace the individual scripts - each one still exists on
its own and can be run independently (useful for debugging one step
without re-running everything). This is a convenience wrapper that runs
the five dataset/training build steps back to back, since those are the
"build once" steps that produce the datasets and trained models everything
else depends on.

NOT included here (run separately, on demand):
  - design_and_test_prompts.py    - manual prompt testing/inspection
  - evaluate_routed_vs_baseline.py - requires app.py already running
  - app.py                         - the live API server, started manually

Usage:
    python run_pipeline.py
"""

import time

import prepare_triage_dataset
import generate_appointment_dataset
import train_baseline_classifier
import train_transformer_classifier
import score_emergency_distress


def section(title):
    print("\n" + "#" * 70)
    print(f"# {title}")
    print("#" * 70 + "\n")


def main():
    start = time.time()

    section("STEP 1/5 - Load and relabel medical_triage_500.jsonl")
    prepare_triage_dataset.main()

    section("STEP 2/5 - Generate Appointment category queries")
    generate_appointment_dataset.main()

    section("STEP 3/5 - Merge datasets, train baseline classifier")
    train_baseline_classifier.main()

    section("STEP 4/5 - Fine-tune transformer classifier (this is the slow one)")
    train_transformer_classifier.main()

    section("STEP 5/5 - Distress scoring and priority ranking")
    score_emergency_distress.main()

    elapsed_min = (time.time() - start) / 60
    section(f"PIPELINE COMPLETE in {elapsed_min:.1f} minutes")
    print("Next steps (run manually, not part of this script):")
    print("  1. python design_and_test_prompts.py   - inspect sample GPT responses")
    print("  2. python app.py                        - start the live API server")
    print("  3. python evaluate_routed_vs_baseline.py - (with app.py running) run the")
    print("     mixed-urgency batch evaluation vs. non-routed baseline")


if __name__ == "__main__":
    main()