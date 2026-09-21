"""
Shared test harness - NOT a test file itself (no 'test_' prefix on
purpose, so pytest/unittest discovery skips it).

app.py loads real ML model weights and a live Gemini client at import
time (module-level code, not inside a function), and calls out to
OpenStreetMap's Overpass/Nominatim APIs at request time. None of that
is available or desirable in an automated test run - the whole point of
Phase 1/2 testing is to isolate app.py's own logic from those external
systems. This module replaces each heavy dependency with a lightweight
in-memory fake (a "driver"/"stub" in Bottom-Up integration testing
terms) BEFORE app.py is imported, so app.py's own module-level loading
code runs against the fakes instead of the real thing.

Each test phase can further override a specific stub's behavior per-test
(e.g. Phase 2 makes the Gemini stub return malformed JSON to test
classify_department's fallback path) by re-assigning the relevant
sys.modules entry's attribute, or by monkeypatching the imported app
module's functions directly - see test_phase2_component_integration.py
for examples of both.
"""
import sys
import types
import json
import os
import tempfile


def _make_stub(name, **attrs):
    m = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(m, k, v)
    sys.modules[name] = m
    return m


class _NoGrad:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class FakeGeminiResponse:
    """Lets a test control exactly what generate_content() returns."""
    def __init__(self, text):
        self.text = text


class FakeGeminiModels:
    """Default behavior: identity-translate plain strings (so
    translate_to_english round-trips English test text unchanged), and
    return a canned string otherwise. Tests override
    `sys.modules['google.genai']._client.models.generate_content` or
    monkeypatch `app.gemini_client.models.generate_content` directly for
    scenario-specific behavior (malformed JSON, an exception, etc.)."""
    def generate_content(self, **kwargs):
        contents = kwargs.get("contents")
        if isinstance(contents, str) and not contents.startswith("Appointment request:"):
            return FakeGeminiResponse(contents)
        return FakeGeminiResponse("stubbed gemini response")


class FakeGeminiClient:
    def __init__(self, *a, **k):
        self.models = FakeGeminiModels()


def import_app_with_stubs():
    """Idempotent: if app.py is already imported (e.g. a previous test
    phase imported it earlier in the same process), returns the same
    module object with its stubs already applied, rather than
    re-stubbing (which would create fresh fake state and could mask a
    real cross-phase state bug)."""
    if "app" in sys.modules:
        return sys.modules["app"]

    class _FakeScalar:
        def __init__(self, value):
            self._value = value

        def item(self):
            return self._value

    torch_stub = _make_stub("torch")
    torch_stub.no_grad = _NoGrad
    torch_stub.softmax = lambda x, dim: [[_FakeScalar(1.0) for _ in row] for row in x]
    torch_stub.argmax = lambda x, dim: types.SimpleNamespace(item=lambda: 0)

    class _FakeTokenizer:
        @classmethod
        def from_pretrained(cls, *a, **k):
            return cls()

        def __call__(self, *a, **k):
            return {}

    class _FakeModel:
        @classmethod
        def from_pretrained(cls, *a, **k):
            return cls()

        def eval(self):
            pass

        def __call__(self, **k):
            return types.SimpleNamespace(logits=[[0]])

    def _fake_pipeline(*a, **k):
        def run(text):
            return [[{"label": "fear", "score": 0.42}]]
        return run

    _make_stub(
        "transformers",
        DistilBertTokenizerFast=_FakeTokenizer,
        DistilBertForSequenceClassification=_FakeModel,
        pipeline=_fake_pipeline,
    )

    fake_label_mapping_path = os.path.join(tempfile.gettempdir(), "_fake_label_mapping.json")
    with open(fake_label_mapping_path, "w") as f:
        json.dump({"0": "Emergency", "1": "Medicine Query", "2": "Appointment"}, f)
    _make_stub("huggingface_hub", hf_hub_download=lambda **k: fake_label_mapping_path)

    genai_stub = _make_stub("google.genai", Client=FakeGeminiClient)
    _make_stub(
        "google.genai.types",
        Content=lambda **k: k, Part=lambda **k: k,
        GenerateContentConfig=lambda **k: k,
    )
    _make_stub("google", genai=genai_stub)
    _make_stub("dotenv", load_dotenv=lambda *a, **k: None)

    # Real pandas is used (it's a plain dependency, no network/model
    # involved) - only read_csv is stubbed, since the real medicine CSV
    # path may not exist in the test environment and tests should
    # control their own fixture data anyway (see reset_medicine_records).
    import pandas as real_pandas

    class _EmptyDF:
        def iterrows(self):
            return iter([])

    pd_stub = _make_stub("pandas")
    for attr in dir(real_pandas):
        if not attr.startswith("_"):
            setattr(pd_stub, attr, getattr(real_pandas, attr))
    pd_stub.read_csv = lambda *a, **k: _EmptyDF()

    os.environ.setdefault("GEMINI_API_KEY", "fake-key-for-tests")

    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    import importlib
    app = importlib.import_module("app")
    return app


def reset_medicine_records(app, records):
    """Replace app.MEDICINE_RECORDS with a small deterministic fixture so
    find_relevant_medicines tests don't depend on (or break when someone
    edits) the real 699-row medicine_dataset.csv."""
    app.MEDICINE_RECORDS = records