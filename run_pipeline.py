"""
run_pipeline.py - Runs the full data preparation + training pipeline in order

This does NOT replace the individual phase scripts - each one still exists
on its own and can be run independently (useful for debugging one step
without re-running everything). This is a convenience wrapper that runs
Phases 1-5 back to back, since those are the "build once" steps that
produce the datasets and trained models everything else depends on.

NOT included here (run separately, on demand):
  - phase6_gpt_prompts.py   - manual prompt testing/inspection
  - phase9_evaluation.py    - requires app.py already running
  - app.py                  - the live API server, started manually

Usage:
    python run_pipeline.py
"""

import time

import phase1_load_data
import phase2_generate_appointments
import phase3_baseline_classifier
import phase4_transformer_classifier
import phase5_distress_ranking


def section(title):
    print("\n" + "#" * 70)
    print(f"# {title}")
    print("#" * 70 + "\n")


def main():
    start = time.time()

    section("PHASE 1 - Load and relabel medical_triage_500.jsonl")
    phase1_load_data.main()

    section("PHASE 2 - Generate Appointment category queries")
    phase2_generate_appointments.main()

    section("PHASE 3 - Merge datasets, train baseline classifier")
    phase3_baseline_classifier.main()

    section("PHASE 4 - Fine-tune transformer classifier (this is the slow one)")
    phase4_transformer_classifier.main()

    section("PHASE 5 - Distress scoring and priority ranking")
    phase5_distress_ranking.main()

    elapsed_min = (time.time() - start) / 60
    section(f"PIPELINE COMPLETE in {elapsed_min:.1f} minutes")
    print("Next steps (run manually, not part of this script):")
    print("  1. python phase6_gpt_prompts.py     - inspect sample GPT responses")
    print("  2. python app.py                    - start the live API server")
    print("  3. python phase9_evaluation.py       - (with app.py running) run the")
    print("     mixed-urgency batch evaluation vs. non-routed baseline")


if __name__ == "__main__":
    main()
