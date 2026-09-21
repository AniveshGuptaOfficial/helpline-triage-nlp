"""
Runs Phase 1 -> Phase 2 -> Phase 3 in strict Bottom-Up order and stops
at the first phase that fails, rather than running every phase
regardless of outcome. This mirrors the actual point of incremental
integration testing: there's no value in checking whether the routes
work correctly (Phase 3) if the component layer under them (Phase 2)
is already broken - fix the lower layer first, then re-run.

Run with: python tests/run_all_phases.py
"""
import subprocess
import sys
import os

PHASES = [
    ("Phase 1 - Unit (pure functions)", "test_phase1_unit.py"),
    ("Phase 2 - Component integration (model/network drivers)", "test_phase2_component_integration.py"),
    ("Phase 3 - System/route integration (Flask test client)", "test_phase3_system_routes.py"),
]

here = os.path.dirname(os.path.abspath(__file__))
python = sys.executable

for label, filename in PHASES:
    print("\n" + "#" * 70)
    print(f"# {label}")
    print("#" * 70)
    result = subprocess.run(
        [python, os.path.join(here, filename)],
        cwd=os.path.dirname(here),
    )
    if result.returncode != 0:
        print(f"\nSTOPPED: {label} failed - fix this before re-running later phases.")
        sys.exit(1)

print("\n" + "#" * 70)
print("# ALL PHASES PASSED (Python backend fully covered, bottom to top)")
print("# Phase 4 (Flutter top-down tests) run separately via `flutter test`")
print("# in helpline_app/ - see the tests/flutter/ files for details.")
print("#" * 70)