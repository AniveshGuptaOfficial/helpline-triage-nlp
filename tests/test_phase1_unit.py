"""
PHASE 1 - UNIT TESTING (bottom layer of the Bottom-Up integration strategy)

Tests app.py's pure functions in complete isolation: no network, no ML
model, no Gemini call, no Flask. Each function is exercised directly with
plain Python inputs and checked against known outputs. This is the
foundation the Phase 2 component-integration tests and Phase 3
route/system tests are built on top of - if anything here fails, every
higher phase is untrustworthy regardless of what it reports.

Run with: python tests/test_phase1_unit.py
(uses the same import-stubbing approach as the other phases so app.py's
module-level model loading doesn't require real weights/network - see
tests/_stub_app_imports.py)
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from _stub_app_imports import import_app_with_stubs, reset_medicine_records

app = import_app_with_stubs()

failures = []
def check(name, cond):
    print(f"[{'PASS' if cond else 'FAIL'}] {name}")
    if not cond:
        failures.append(name)

# ---------------------------------------------------------------------
# resolve_language_name
# ---------------------------------------------------------------------
check("resolve_language_name('hi') -> Hindi", app.resolve_language_name("hi") == "Hindi")
check("resolve_language_name('ta') -> Tamil", app.resolve_language_name("ta") == "Tamil")
check("resolve_language_name unknown code -> English fallback",
      app.resolve_language_name("zz") == "English")
check("resolve_language_name(None) -> English fallback",
      app.resolve_language_name(None) == "English")

# ---------------------------------------------------------------------
# check_emergency_override
# ---------------------------------------------------------------------
check("override: 'can't breathe' detected",
      app.check_emergency_override("I want an appointment, he can't breathe"))
check("override: 'chest pain' detected",
      app.check_emergency_override("sudden severe chest pain"))
check("override: case-insensitive",
      app.check_emergency_override("CAN'T BREATHE at all"))
check("override: benign text NOT flagged",
      not app.check_emergency_override("I'd like to book a routine check-up"))
check("override: empty string NOT flagged",
      not app.check_emergency_override(""))

# ---------------------------------------------------------------------
# check_worsening_high_risk (requires BOTH a worsening AND a high-risk
# keyword in the SAME text - neither alone should trigger)
# ---------------------------------------------------------------------
check("worsening+high-risk: both present -> True",
      app.check_worsening_high_risk("my chest pain is getting worse"))
check("worsening+high-risk: only worsening -> False",
      not app.check_worsening_high_risk("it's getting worse"))
check("worsening+high-risk: only high-risk -> False",
      not app.check_worsening_high_risk("I have chest pain"))
check("worsening+high-risk: neither -> False",
      not app.check_worsening_high_risk("I have a mild headache"))

# ---------------------------------------------------------------------
# haversine_miles
# ---------------------------------------------------------------------
d = app.haversine_miles(40.7128, -74.0060, 34.0522, -118.2437)  # NYC -> LA
check("haversine NYC-LA within 2% of known ~2451 mi", abs(d - 2451) / 2451 < 0.02)
check("haversine same point == 0",
      abs(app.haversine_miles(12.97, 79.15, 12.97, 79.15)) < 1e-9)
check("haversine is symmetric (A->B == B->A)",
      abs(app.haversine_miles(10, 20, 30, 40) - app.haversine_miles(30, 40, 10, 20)) < 1e-9)

# ---------------------------------------------------------------------
# find_relevant_medicines (needs MEDICINE_RECORDS populated - inject a
# small deterministic fixture rather than depending on the real 699-row
# dataset, so this test doesn't silently break if that CSV changes)
# ---------------------------------------------------------------------
reset_medicine_records(app, [
    {"medicine_name": "Paracetamol", "description": "Pain/fever reliever.",
     "uses": ["fever", "headache", "pain"], "side_effects": ["nausea"], "disclaimer": "d"},
    {"medicine_name": "Cetirizine", "description": "Antihistamine.",
     "uses": ["allergy", "itching", "runny nose"], "side_effects": ["drowsiness"], "disclaimer": "d"},
    {"medicine_name": "Omeprazole", "description": "Acid reducer.",
     "uses": ["acidity", "heartburn"], "side_effects": ["headache"], "disclaimer": "d"},
])
results = app.find_relevant_medicines("I have a bad headache and fever")
check("find_relevant_medicines: matches on 'uses' keywords",
      any(r["medicine_name"] == "Paracetamol" for r in results))
check("find_relevant_medicines: no match returns empty list",
      app.find_relevant_medicines("completely unrelated text about cars") == [])
results2 = app.find_relevant_medicines("does paracetamol help with headache and fever")
check("find_relevant_medicines: exact medicine-name mention scores higher (sorted first)",
      results2[0]["medicine_name"] == "Paracetamol")
check("find_relevant_medicines: respects top_k",
      len(app.find_relevant_medicines("headache fever allergy itching acidity heartburn", top_k=2)) <= 2)

# ---------------------------------------------------------------------
# build_medicine_context
# ---------------------------------------------------------------------
check("build_medicine_context: None for empty matches", app.build_medicine_context([]) is None)
ctx = app.build_medicine_context([
    {"medicine_name": "Paracetamol", "description": "Pain/fever reliever.", "uses": ["fever", "pain"]}
])
check("build_medicine_context: includes medicine name", "Paracetamol" in ctx)
check("build_medicine_context: includes uses", "fever" in ctx and "pain" in ctx)

# ---------------------------------------------------------------------
# build_department_context
# ---------------------------------------------------------------------
check("build_department_context: None for falsy input", app.build_department_context(None) is None)
dctx = app.build_department_context({
    "department": "Cardiology", "confidence": "high", "rationale": "chest pain mentioned", "secondary": None,
})
check("build_department_context: includes department", "Cardiology" in dctx)
check("build_department_context: omits secondary line when None",
      "Secondary" not in dctx)
dctx2 = app.build_department_context({
    "department": "Cardiology", "confidence": "medium", "rationale": "r", "secondary": "General Medicine",
})
check("build_department_context: includes secondary line when present",
      "General Medicine" in dctx2 and "Secondary" in dctx2)

# ---------------------------------------------------------------------
# build_booking_payload (address-provided path only here - the
# reverse-geocode-fallback path needs a network stub and belongs to
# Phase 2, tested in test_phase2_component_integration.py)
# ---------------------------------------------------------------------
payload = app.build_booking_payload(
    hospital_name="Test Hospital", hospital_address="123 Main St",
    hospital_lat=12.9, hospital_lon=79.1, category="Emergency",
)
check("booking payload: Emergency confirmation text exact match",
      payload["confirmation_text"] == "Emergency slot secured at Test Hospital.")
check("booking payload: keeps given address unchanged (no network call needed)",
      payload["hospital_address"] == "123 Main St")
check("booking payload: maps_intent_url uses google.navigation scheme",
      payload["maps_intent_url"] == "google.navigation:q=12.9,79.1&mode=d")
check("booking payload: maps_web_url is a google maps directions link",
      "google.com/maps/dir" in payload["maps_web_url"] and "12.9,79.1" in payload["maps_web_url"])
check("booking payload: static_map_url present",
      payload["static_map_url"].startswith("https://staticmap.openstreetmap.de"))

payload2 = app.build_booking_payload(
    hospital_name="Clinic X", hospital_address="456 Side Rd",
    hospital_lat=1.0, hospital_lon=2.0, category="Appointment",
    appointment_time="Tomorrow 10 AM",
)
check("booking payload: Appointment confirmation includes given time",
      payload2["confirmation_text"] == "Appointment confirmation at Clinic X for Tomorrow 10 AM.")

payload3 = app.build_booking_payload(
    hospital_name="Clinic Y", hospital_address="789 Rd",
    hospital_lat=1.0, hospital_lon=2.0, category="Appointment",
)
check("booking payload: Appointment falls back to generic phrase when no time given",
      payload3["confirmation_text"] == "Appointment confirmation at Clinic Y for your requested time.")

print("\n" + "=" * 60)
print(f"PHASE 1 (Unit): {len(failures)} failure(s)" if failures else "PHASE 1 (Unit): ALL TESTS PASSED")
if failures:
    print(failures)
    sys.exit(1)