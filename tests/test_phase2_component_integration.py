"""
PHASE 2 - BOTTOM-UP COMPONENT INTEGRATION TESTING

Builds on Phase 1 (which proved the pure functions correct in
isolation) by integrating the next layer up: functions that depend on
an external system (the transformer classifier, the emotion model,
Gemini, or the Overpass/Nominatim network APIs). Each external system
is replaced with a controllable DRIVER for this phase - a fake that
stands in for a component that either isn't safe to call for real in a
test run (paid/rate-limited APIs) or isn't available at all in this
environment - so we can verify app.py's OWN logic (parsing, fallback
behavior, error handling, sorting) independent of whether the real
external service is up, slow, or rate-limiting us right now.

This is genuine Bottom-Up integration: Phase 1's pure functions
(haversine_miles, etc.) are exercised again here as real collaborators
inside find_nearby_hospitals, not re-stubbed - only the true external
boundary (the HTTP call itself) is faked.

Run with: python tests/test_phase2_component_integration.py
"""
import sys
import os
import types
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from _stub_app_imports import import_app_with_stubs, FakeGeminiResponse

app = import_app_with_stubs()

failures = []
def check(name, cond):
    print(f"[{'PASS' if cond else 'FAIL'}] {name}")
    if not cond:
        failures.append(name)


# =======================================================================
# classify_query - driver: fake tokenizer/model already wired in
# import_app_with_stubs (always predicts index 0). Real coverage here is
# of the *plumbing*: tensor -> softmax -> argmax -> LABEL_MAPPING lookup
# -> (label, confidence) tuple shape - not the model's actual judgment
# quality, which is a data-science evaluation concern (see
# evaluate_routed_vs_baseline.py), not a code-correctness one.
# =======================================================================
label, confidence = app.classify_query("any text at all")
check("classify_query returns a (label, confidence) tuple",
      isinstance(label, str) and isinstance(confidence, float))
check("classify_query label comes from LABEL_MAPPING",
      label in app.LABEL_MAPPING.values())
check("classify_query confidence is a valid probability", 0.0 <= confidence <= 1.0)


# =======================================================================
# score_distress - driver: fake emotion pipeline returns a fixed
# fear=0.42 score for any input.
# =======================================================================
check("score_distress extracts the 'fear' score",
      app.score_distress("any text") == 0.42)

# Swap the driver mid-test to verify the "no 'fear' label present"
# fallback path, which the default driver never exercises.
original_pipeline = app.emotion_classifier
app.emotion_classifier = lambda text: [[{"label": "joy", "score": 0.9}]]
check("score_distress returns None when 'fear' label is absent",
      app.score_distress("any text") is None)
app.emotion_classifier = original_pipeline


# =======================================================================
# translate_to_english - driver: identity-translates plain English
# strings by default (see FakeGeminiResponse in the shared harness).
# =======================================================================
check("translate_to_english passes through already-English text",
      app.translate_to_english("I have a headache") == "I have a headache")

# Swap in a driver that raises, to verify the safe fallback path (return
# original text unchanged rather than crashing the whole request).
class _RaisingModels:
    def generate_content(self, **k):
        raise RuntimeError("simulated Gemini outage")
original_client = app.gemini_client
app.gemini_client = types.SimpleNamespace(models=_RaisingModels())
check("translate_to_english falls back to original text if Gemini call fails",
      app.translate_to_english("मुझे और मदद चाहिए") == "मुझे और मदद चाहिए")
app.gemini_client = original_client


# =======================================================================
# classify_department - driver: controllable Gemini response text
# =======================================================================
class _JsonModels:
    def __init__(self, text):
        self._text = text
    def generate_content(self, **k):
        return FakeGeminiResponse(self._text)

app.gemini_client = types.SimpleNamespace(models=_JsonModels(
    '{"department": "Cardiology", "confidence": "high", '
    '"rationale": "chest pain mentioned", "secondary": null}'
))
result = app.classify_department("I have chest pain, need a checkup")
check("classify_department parses a well-formed JSON response",
      result["department"] == "Cardiology" and result["confidence"] == "high")

# Gemini wrapping its JSON in markdown fences despite being told not to -
# the defensive cleanup code path.
app.gemini_client = types.SimpleNamespace(models=_JsonModels(
    '```json\n{"department": "Dermatology", "confidence": "medium", '
    '"rationale": "skin issue", "secondary": null}\n```'
))
result2 = app.classify_department("I have a skin rash")
check("classify_department strips ```json fences before parsing",
      result2["department"] == "Dermatology")

# Malformed JSON -> safe General Medicine fallback, not a crash.
app.gemini_client = types.SimpleNamespace(models=_JsonModels("not valid json at all {{{"))
result3 = app.classify_department("something")
check("classify_department falls back to General Medicine on malformed JSON",
      result3["department"] == "General Medicine" and result3["confidence"] == "low")

# Department name outside the fixed list -> still falls back safely
# rather than trusting an invented department string.
app.gemini_client = types.SimpleNamespace(models=_JsonModels(
    '{"department": "Astrology", "confidence": "high", "rationale": "r", "secondary": null}'
))
result4 = app.classify_department("something")
check("classify_department rejects a department outside the fixed list",
      result4["department"] == "General Medicine")

# Gemini call raising entirely -> fallback, never propagates the exception.
app.gemini_client = types.SimpleNamespace(models=_RaisingModels())
result5 = app.classify_department("something")
check("classify_department falls back cleanly if the Gemini call raises",
      result5["department"] == "General Medicine" and result5["confidence"] == "low")
app.gemini_client = original_client


# =======================================================================
# generate_response - driver: capture what was actually sent to Gemini
# so we can verify the right system prompt / user-message shape was
# built per category, without needing a real model response.
# =======================================================================
captured = {}
class _CapturingModels:
    def generate_content(self, **kwargs):
        captured.clear()
        captured.update(kwargs)
        return FakeGeminiResponse("ok")

app.gemini_client = types.SimpleNamespace(models=_CapturingModels())

app.generate_response("Emergency", "chest pain", distress_score=0.87)
check("generate_response (Emergency) uses the Emergency system prompt",
      captured["config"]["system_instruction"] == app.SYSTEM_PROMPTS["Emergency"])
check("generate_response (Emergency) includes the distress score in the message",
      "0.870" in captured["contents"])

app.generate_response("Medicine Query", "headache remedy",
                       medicine_context="Reference medicine information: ...")
check("generate_response (Medicine Query) includes medicine_context when provided",
      "Reference medicine information" in captured["contents"])

app.generate_response("Appointment", "book a checkup",
                       department_context="Detected department: General Medicine.")
check("generate_response (Appointment) includes department_context when provided",
      "Detected department" in captured["contents"])

app.generate_response("Medicine Query", "headache remedy", language_name="Hindi")
check("generate_response wraps the system prompt with a language instruction when non-English",
      "Hindi" in captured["config"]["system_instruction"])
app.gemini_client = original_client


# =======================================================================
# find_nearby_hospitals - driver: fake requests.post standing in for the
# Overpass API. Exercises app.py's OWN parsing/filtering/sorting logic,
# not OpenStreetMap's actual data for any real coordinate.
# =======================================================================
class _FakeResponse:
    def __init__(self, json_data, status_ok=True):
        self._json_data = json_data
        self._status_ok = status_ok
    def raise_for_status(self):
        if not self._status_ok:
            raise RuntimeError("simulated HTTP error")
    def json(self):
        return self._json_data

TEST_LAT, TEST_LON = 12.9724, 79.1581

def _overpass_element(name, lat, lon, rating=None, elem_type="node"):
    tags = {"name": name}
    if rating is not None:
        tags["rating"] = str(rating)
    el = {"type": elem_type, "tags": tags}
    if elem_type == "node":
        el["lat"], el["lon"] = lat, lon
    else:
        el["center"] = {"lat": lat, "lon": lon}
    return el

original_requests_post = app.http_requests.post

def _stub_overpass(elements):
    def _post(url, **kwargs):
        return _FakeResponse({"elements": elements})
    app.http_requests.post = _post

# Near/far/unrated hospitals, plus a "way" element (uses center, not lat/lon
# directly) and a same-distance-tier tiebreak on rating.
_stub_overpass([
    _overpass_element("Far Hospital", TEST_LAT + 0.05, TEST_LON, rating=4.9),
    _overpass_element("Near Hospital", TEST_LAT + 0.005, TEST_LON, rating=None),
    _overpass_element("Way-type Clinic", TEST_LAT + 0.005, TEST_LON, rating=None, elem_type="way"),
    _overpass_element("No Name Hospital", TEST_LAT + 0.001, TEST_LON),  # will be given no name below
])
# Strip the name from the last one to test the "skip unnamed results" filter.
app.http_requests.post.__self__ if False else None  # no-op, keeping structure simple
elements_no_name = [
    _overpass_element("Far Hospital", TEST_LAT + 0.05, TEST_LON, rating=4.9),
    _overpass_element("Near Hospital", TEST_LAT + 0.005, TEST_LON, rating=None),
    {"type": "node", "lat": TEST_LAT + 0.001, "lon": TEST_LON, "tags": {}},  # no name at all
]
_stub_overpass(elements_no_name)
results = app.find_nearby_hospitals(TEST_LAT, TEST_LON)
check("find_nearby_hospitals skips elements with no name tag",
      all(h["name"] for h in results) and len(results) == 2)
check("find_nearby_hospitals sorts nearest first",
      results[0]["name"] == "Near Hospital")

# Radius filtering: a hospital technically returned by Overpass but
# outside the requested radius (can happen due to Overpass's bounding
# behavior) must still be excluded by app.py's own distance check.
_stub_overpass([
    _overpass_element("Just Outside", TEST_LAT + 1.0, TEST_LON),  # ~69 miles away
    _overpass_element("Just Inside", TEST_LAT + 0.01, TEST_LON),
])
results2 = app.find_nearby_hospitals(TEST_LAT, TEST_LON, radius_miles=8)
check("find_nearby_hospitals excludes results beyond the requested radius",
      all(h["distance_miles"] <= 8 for h in results2) and len(results2) == 1)

# Primary mirror fails, secondary succeeds -> should still return results,
# not an empty list.
call_count = {"n": 0}
def _post_first_fails(url, **kwargs):
    call_count["n"] += 1
    if url == app.OVERPASS_URLS[0]:
        raise RuntimeError("simulated primary mirror outage")
    return _FakeResponse({"elements": [_overpass_element("Backup Result", TEST_LAT + 0.01, TEST_LON)]})
app.http_requests.post = _post_first_fails
results3 = app.find_nearby_hospitals(TEST_LAT, TEST_LON)
check("find_nearby_hospitals falls back to a secondary Overpass mirror",
      len(results3) == 1 and results3[0]["name"] == "Backup Result")

# All mirrors fail -> empty list, not an exception propagating up to the
# Flask route (which would otherwise 500 the whole /hospitals request).
def _post_all_fail(url, **kwargs):
    raise RuntimeError("simulated total outage")
app.http_requests.post = _post_all_fail
results4 = app.find_nearby_hospitals(TEST_LAT, TEST_LON)
check("find_nearby_hospitals returns [] (not an exception) when all mirrors fail",
      results4 == [])

app.http_requests.post = original_requests_post


# =======================================================================
# reverse_geocode_address - driver: fake requests.get for Nominatim
# =======================================================================
original_requests_get = app.http_requests.get

app.http_requests.get = lambda *a, **k: _FakeResponse({"display_name": "123 Fake St, Vellore"})
check("reverse_geocode_address returns display_name on success",
      app.reverse_geocode_address(12.9, 79.1) == "123 Fake St, Vellore")

def _get_raises(*a, **k):
    raise RuntimeError("simulated Nominatim outage")
app.http_requests.get = _get_raises
check("reverse_geocode_address returns None (not an exception) on failure",
      app.reverse_geocode_address(12.9, 79.1) is None)

app.http_requests.get = original_requests_get


# =======================================================================
# build_booking_payload - the reverse-geocode FALLBACK path specifically
# (the address-provided path was already covered in Phase 1). This is
# the one branch of build_booking_payload that has a real dependency,
# which is exactly why it belongs in Phase 2, not Phase 1.
# =======================================================================
app.http_requests.get = lambda *a, **k: _FakeResponse({"display_name": "Resolved Address, Vellore"})
payload = app.build_booking_payload(
    hospital_name="No-Address Hospital", hospital_address="",
    hospital_lat=12.9, hospital_lon=79.1, category="Emergency",
)
check("build_booking_payload falls back to reverse-geocoding when address is empty",
      payload["hospital_address"] == "Resolved Address, Vellore")

payload_placeholder = app.build_booking_payload(
    hospital_name="Placeholder Hospital", hospital_address="Address not available",
    hospital_lat=12.9, hospital_lon=79.1, category="Emergency",
)
check("build_booking_payload also triggers reverse-geocode on the literal placeholder string",
      payload_placeholder["hospital_address"] == "Resolved Address, Vellore")

app.http_requests.get = _get_raises
payload_both_fail = app.build_booking_payload(
    hospital_name="Still No Address", hospital_address="",
    hospital_lat=12.9, hospital_lon=79.1, category="Emergency",
)
check("build_booking_payload settles on 'Address not available' if reverse-geocode also fails",
      payload_both_fail["hospital_address"] == "Address not available")

app.http_requests.get = original_requests_get


print("\n" + "=" * 60)
print(f"PHASE 2 (Component Integration): {len(failures)} failure(s)" if failures
      else "PHASE 2 (Component Integration): ALL TESTS PASSED")
if failures:
    print(failures)
    sys.exit(1)