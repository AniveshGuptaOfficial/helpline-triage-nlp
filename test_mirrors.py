import requests
query = '[out:json][timeout:15];node["amenity"="hospital"](around:13000,12.9724,79.1581);out center tags;'
urls = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter'
]
for url in urls:
    print(f"Trying {url}")
    try:
        r = requests.post(url, data={'data': query}, headers={'User-Agent': 'VaidyumHelplineTriage/1.0'}, timeout=10)
        print(f'{url}: {r.status_code}')
        if r.status_code == 200:
            print(len(r.json().get('elements', [])))
    except Exception as e:
        print(f'{url}: Error {e}')
