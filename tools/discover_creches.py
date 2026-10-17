#!/usr/bin/env python3
"""Découverte (CI) : OpenStreetMap (Overpass), APUR, API Adresse."""
import collections
import json
import urllib.parse
import urllib.request


def fetch(url, data=None):
    request = urllib.request.Request(url, data=data, headers={"User-Agent": "appc-badgeuse (contact: christophe.amalric@appc.paris)"})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


QUERY = """
[out:json][timeout:120];
area["ref:INSEE"="75056"]["boundary"="administrative"]->.paris;
(
  nwr["amenity"="childcare"](area.paris);
  nwr["amenity"="kindergarten"](area.paris);
);
out center tags;
"""
try:
    body = fetch("https://overpass-api.de/api/interpreter", urllib.parse.urlencode({"data": QUERY}).encode())
    elements = json.loads(body)["elements"]
    print("OSM éléments :", len(elements))
    counter = collections.Counter()
    for element in elements:
        tags = element.get("tags", {})
        key = (tags.get("amenity"), tags.get("kindergarten:FR"), tags.get("school:FR"), tags.get("childcare"))
        counter[key] += 1
    for key, count in counter.most_common(25):
        print(" ", count, key)
    with_address = sum(1 for e in elements if "addr:street" in e.get("tags", {}))
    with_name = sum(1 for e in elements if "name" in e.get("tags", {}))
    print("avec nom :", with_name, "avec rue :", with_address)
    names = collections.Counter(e.get("tags", {}).get("name", "").split(" ")[0].lower() for e in elements)
    print("premiers mots des noms :", names.most_common(20))
    for element in elements[:12]:
        print(json.dumps(element, ensure_ascii=False)[:400])
except Exception as error:  # noqa: BLE001
    print("Overpass ERREUR", error)

try:
    hub = json.loads(fetch("https://opendata.apur.org/api/search/v1/collections/all/items?" + urllib.parse.urlencode({"q": "petite enfance", "limit": 10})))
    for feature in hub.get("features", []):
        props = feature.get("properties", {})
        print("APUR :", props.get("title"), "|", props.get("url") or feature.get("id"))
except Exception as error:  # noqa: BLE001
    print("APUR ERREUR", error)

try:
    reverse = json.loads(fetch("https://api-adresse.data.gouv.fr/reverse/?lon=2.3430&lat=48.8640"))
    print("API Adresse :", reverse["features"][0]["properties"]["label"])
except Exception as error:  # noqa: BLE001
    print("API Adresse ERREUR", error)
