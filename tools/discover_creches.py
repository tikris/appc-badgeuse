#!/usr/bin/env python3
"""Découverte (CI) : couche APUR « équipements ponctuels petite enfance »."""
import collections
import json
import urllib.parse
import urllib.request

LAYER = "https://carto2.apur.org/apur/rest/services/OPENDATA/EQUIPEMENT_PONCTUEL/MapServer/2"


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "appc-badgeuse"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)


info = get(LAYER + "?f=json")
print("Nom :", info.get("name"), "| maxRecordCount :", info.get("maxRecordCount"))
print("Description :", (info.get("description") or "")[:600])
print("Copyright :", info.get("copyrightText"))
print("Champs :", [(f["name"], f.get("alias"), f.get("type")) for f in info.get("fields", [])])
count = get(LAYER + "/query?" + urllib.parse.urlencode({"where": "1=1", "returnCountOnly": "true", "f": "json"}))
print("Nombre :", count)
data = get(LAYER + "/query?" + urllib.parse.urlencode(
    {"where": "1=1", "outFields": "*", "outSR": "4326", "f": "geojson", "resultRecordCount": 2000}))
features = data["features"]
print("Reçus :", len(features))
for key in features[0]["properties"]:
    values = collections.Counter(str(f["properties"].get(key)) for f in features)
    print(f"  {key}: {len(values)} valeurs, ex. {values.most_common(6)}")
for feature in features[:5]:
    print(json.dumps(feature, ensure_ascii=False)[:600])
