"""
PHASE 3 - SYSTEM / ROUTE INTEGRATION TESTING

Builds on Phase 1 (pure functions) and Phase 2 (component drivers) by
integrating the top-most layer of the Python backend: the Flask routes
that wire everything together into the actual HTTP contract the Flutter
app talks to. Flask's test client acts as the DRIVER here, standing in
for the real top of the whole system (the mobile app) - it sends real
HTTP-shaped requests and inspects real HTTP-shaped responses, but
in-process, without needing a running server or a physical/emulated
phone.

This is the last phase testable from the Python side alone. Phase 4
(test/ in the Flutter project) tests the actual top layer - the app
that would be the real caller of these routes - using a Top-Down
strategy with a mocked HTTP client standing in for this exact backend.
The two phases meet at the JSON request/response contract tested here,
which is the "seam" of the overall Sandwich/Hybrid strategy.

Run with: python tests/test_phase3_system_routes.py
"""
import sys
import os
import types
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from _stub_app_imports import import_app_with_stubs, FakeGeminiResponse

app_module = import_app_with_stubs()

# classify_query is swapped out at the route level (rather than via its
# own model driver) so each route test can control the category
# independently of Phase 2's model-plumbing tests - this is standard
# Bottom-Up practice: once a lower layer is proven correct on its own
# (Phase 2), higher-layer tests are free to stub it directly instead of
# re-deriving its behavior indirectly through fake model weights.
CLASSIFY_AS = {"value": "Emergency"}
def fake_classify_query(text):
    return CLASSIFY_AS["value"], 0.93
app_module.classify_query = fake_classify_query

def fake_find_nearby(lat, lon, radius_miles=8, limit=15):
    hospitals = [
        {"name": "Far Hospital", "lat": lat + 0.05, "lon": lon, "distance_miles": 3.5,
         "rating": 4.8, "address": "Far Rd", "phone": None},
        {"name": "Near Hospital", "lat": lat + 0.01, "lon": lon, "distance_miles": 0.7,
         "rating": None, "address": "Near St", "phone": "+911234567"},
    ]
    hospitals.sort(key=lambda h: (h["distance_miles"], -(h["rating"] or 0)))
    return hospitals
app_module.find_nearby_hospitals = fake_find_nearby

client = app_module.app.test_client()

failures = []
def check(name, cond, extra=""):
    print(f"[{'PASS' if cond else 'FAIL'}] {name} {extra}")
    if not cond:
        failures.append(name)


# ---------------------------------------------------------------------
# /health
# ---------------------------------------------------------------------
r = client.get("/health")
check("/health -> 200", r.status_code == 200)
check("/health -> status ok", r.get_json().get("status") == "ok")


# ---------------------------------------------------------------------
# /hospitals
# ---------------------------------------------------------------------
r = client.post("/hospitals", json={"latitude": 12.97, "longitude": 79.15})
data = r.get_json()
check("/hospitals -> 200", r.status_code == 200)
check("/hospitals -> sorted nearest-first", data["hospitals"][0]["name"] == "Near Hospital")
check("/hospitals -> count matches list length", data["count"] == len(data["hospitals"]))
check("/hospitals -> default radius echoed", data["radius_miles"] == 8)

r = client.post("/hospitals", json={"latitude": 12.97})
check("/hospitals missing longitude -> 400", r.status_code == 400)

r = client.post("/hospitals", json={"latitude": "not-a-number", "longitude": 79.15})
check("/hospitals non-numeric latitude -> 400", r.status_code == 400)

r = client.post("/hospitals", json={})
check("/hospitals empty body -> 400", r.status_code == 400)


# ---------------------------------------------------------------------
# /book_hospital
# ---------------------------------------------------------------------
r = client.post("/book_hospital", json={
    "hospital_name": "Near Hospital", "hospital_address": "Near St",
    "hospital_lat": 12.98, "hospital_lon": 79.15, "category": "Emergency",
})
data = r.get_json()
check("/book_hospital -> 200", r.status_code == 200)
check("/book_hospital -> confirmation text",
      data["confirmation_text"] == "Emergency slot secured at Near Hospital.")
check("/book_hospital -> returns maps_intent_url", "maps_intent_url" in data)
check("/book_hospital -> returns maps_web_url", "maps_web_url" in data)
check("/book_hospital -> returns static_map_url", "static_map_url" in data)

r = client.post("/book_hospital", json={
    "hospital_name": "Clinic X", "hospital_address": "456 Rd",
    "hospital_lat": 1.0, "hospital_lon": 2.0, "category": "Appointment",
    "appointment_time": "Tomorrow 10 AM",
})
check("/book_hospital Appointment -> confirmation includes given time",
      r.get_json()["confirmation_text"] == "Appointment confirmation at Clinic X for Tomorrow 10 AM.")

r = client.post("/book_hospital", json={"hospital_name": "X"})
check("/book_hospital missing lat/lon -> 400", r.status_code == 400)


# ---------------------------------------------------------------------
# /predict
# ---------------------------------------------------------------------
CLASSIFY_AS["value"] = "Emergency"
r = client.post("/predict", json={"query": "severe chest pain"})
data = r.get_json()
check("/predict -> 200", r.status_code == 200)
check("/predict Emergency -> category correct", data["category"] == "Emergency")
check("/predict Emergency -> escalation_flag true", data["escalation_flag"] is True)
check("/predict Emergency -> hospital_lookup_required true", data["hospital_lookup_required"] is True)
check("/predict Emergency -> distress_score present", data["distress_score"] is not None)

CLASSIFY_AS["value"] = "Medicine Query"
r = client.post("/predict", json={"query": "what helps with a headache"})
data = r.get_json()
check("/predict Medicine Query -> hospital_lookup_required false", data["hospital_lookup_required"] is False)
check("/predict Medicine Query -> escalation_flag false", data["escalation_flag"] is False)

CLASSIFY_AS["value"] = "Appointment"
r = client.post("/predict", json={"query": "I want to book a checkup"})
data = r.get_json()
check("/predict Appointment -> hospital_lookup_required true", data["hospital_lookup_required"] is True)
check("/predict Appointment -> has a department (fallback General Medicine ok)",
      data["department"] == "General Medicine")

r = client.post("/predict", json={"query": "   "})
check("/predict blank query -> 400", r.status_code == 400)

r = client.post("/predict", json={})
check("/predict missing query key -> 400", r.status_code == 400)


# ---------------------------------------------------------------------
# /chat
# ---------------------------------------------------------------------
CLASSIFY_AS["value"] = "Appointment"
r = client.post("/chat", json={
    "message": "I want an appointment, he can't breathe", "history": [],
})
data = r.get_json()
check("/chat emergency-override phrase escalates even when classified Appointment",
      data["emergency_override"] is True and data["category"] == "Emergency")
check("/chat -> hospital_lookup_required true after override", data["hospital_lookup_required"] is True)

CLASSIFY_AS["value"] = "Medicine Query"
r = client.post("/chat", json={
    "message": "it's getting worse",
    "history": [{"role": "user", "text": "I have chest pain"}, {"role": "model", "text": "..."}],
    "category": "Medicine Query",
})
data = r.get_json()
check("/chat re-triages to Emergency on worsening+high-risk mid-conversation",
      data["re_triaged_to_emergency"] is True and data["category"] == "Emergency")

# SOS follow-up chip: forces Emergency even though its own words carry
# no red-flag keywords and the classifier would read it as low-urgency.
CLASSIFY_AS["value"] = "Medicine Query"
r = client.post("/chat", json={
    "message": "I need more help",
    "history": [{"role": "user", "text": "I have a mild headache"},
                {"role": "model", "text": "..."}],
    "category": "Medicine Query",
    "follow_up_intent": "sos",
})
data = r.get_json()
check("/chat SOS follow-up intent forces Emergency regardless of classifier",
      data["category"] == "Emergency")
check("/chat SOS follow-up intent sets re_triaged_to_emergency",
      data["re_triaged_to_emergency"] is True)
check("/chat SOS follow-up intent computes a distress_score",
      data["distress_score"] is not None)

CLASSIFY_AS["value"] = "Emergency"
r = client.post("/chat", json={
    "message": "I need more help",
    "history": [{"role": "user", "text": "severe chest pain"}, {"role": "model", "text": "..."}],
    "category": "Emergency",
    "follow_up_intent": "sos",
})
data = r.get_json()
check("/chat SOS intent on an already-Emergency thread stays Emergency",
      data["category"] == "Emergency")
check("/chat SOS intent on an already-Emergency thread doesn't re-flag re_triaged_to_emergency",
      data["re_triaged_to_emergency"] is False)

r = client.post("/chat", json={})
check("/chat missing message -> 400", r.status_code == 400)

r = client.post("/chat", json={"message": "   "})
check("/chat blank message -> 400", r.status_code == 400)


print("\n" + "=" * 60)
print(f"PHASE 3 (System/Route Integration): {len(failures)} failure(s)" if failures
      else "PHASE 3 (System/Route Integration): ALL TESTS PASSED")
if failures:
    print(failures)
    sys.exit(1)