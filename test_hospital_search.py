"""
Quick standalone test script - checks whether hospital search is working,
without going through the Flutter app at all.

Run this with:  python test_hospital_search.py

It does two things:
1. Queries OpenStreetMap's Overpass API directly, for a fixed test location
   (VIT/Vellore coordinates from your emulator screenshot).
2. Queries your own local Flask /hospitals endpoint with the same
   coordinates (requires `python app.py` already running in another
   terminal).

Compare the two outputs:
- If (1) returns hospitals but (2) doesn't -> bug is in find_nearby_hospitals()
  in app.py (parsing/filtering logic).
- If both return nothing -> OpenStreetMap doesn't have hospitals tagged
  within range of this exact point (a real data-coverage gap, not a bug).
- If both return hospitals -> the backend is fine; the issue is upstream,
  in what the Flutter app is sending (stale build / wrong coordinates).
"""

import json
import requests

TEST_LAT = 12.9724
TEST_LON = 79.1581

OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
# Overpass rejects requests with a generic/default User-Agent (406 Not
# Acceptable) - requests' default UA gets blocked, so a descriptive one
# is required.
HEADERS = {"User-Agent": "VaidyumHelplineTriage/1.0 (BCSE409L course project)"}


def test_raw_overpass():
    print("=" * 60)
    print("1. Testing OpenStreetMap Overpass API directly")
    print("=" * 60)
    query = f"""
    [out:json][timeout:15];
    (
      node["amenity"="hospital"](around:13000,{TEST_LAT},{TEST_LON});
      way["amenity"="hospital"](around:13000,{TEST_LAT},{TEST_LON});
    );
    out center tags;
    """
    for url in OVERPASS_URLS:
        print(f"\nTrying {url} ...")
        try:
            resp = requests.post(url, data={"data": query}, headers=HEADERS, timeout=20)
            print(f"  Status code: {resp.status_code}")
            resp.raise_for_status()
            elements = resp.json().get("elements", [])
            print(f"  Raw elements returned: {len(elements)}")
            for el in elements[:10]:
                tags = el.get("tags", {})
                print(f"    - {tags.get('name', '(no name tag)')}  [{el.get('type')}]")
            if not elements:
                print("  (empty - OSM has no hospital-tagged nodes/ways in this radius)")
            return  # stop after first mirror that responds successfully
        except Exception as e:
            print(f"  ERROR: {e}")
    print("\nAll mirrors failed.")


def test_local_backend():
    print()
    print("=" * 60)
    print("2. Testing your local Flask /hospitals endpoint")
    print("=" * 60)
    try:
        resp = requests.post(
            "http://127.0.0.1:5000/hospitals",
            json={"latitude": TEST_LAT, "longitude": TEST_LON},
            timeout=20,
        )
        print(f"Status code: {resp.status_code}")
        print(json.dumps(resp.json(), indent=2))
    except requests.exceptions.ConnectionError:
        print("Could not connect - is `python app.py` running in another terminal?")
    except Exception as e:
        print(f"ERROR calling local backend: {e}")


if __name__ == "__main__":
    test_raw_overpass()
    test_local_backend()