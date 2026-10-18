#!/usr/bin/env python3
"""Exploration ponctuelle des sources ouvertes de crèches parisiennes (workflow « Sources crèches »).

Affiche, pour chaque source candidate, le volume de données et si la crèche témoin
« Grange aux Belles » (10e) y figure. Sert à choisir la source de tools/fetch_creches.py.
"""
import json
import re
import unicodedata
import urllib.parse
import urllib.request

USER_AGENT = "appc-badgeuse (https://github.com/tikris/appc-badgeuse)"


def get(url, data=None, timeout=120):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


def fold(text):
    return "".join(c for c in unicodedata.normalize("NFD", str(text).lower()) if unicodedata.category(c) != "Mn")


def section(title, function):
    print(f"\n===== {title} =====", flush=True)
    try:
        function()
    except Exception as error:  # noqa: BLE001
        print("ERREUR :", repr(error))


def paris_data():
    seen = {}
    for term in ["creche", "crèches", "petite enfance", "accueil du jeune enfant", "equipements", "lieux", "etablissements"]:
        where = urllib.parse.quote(f'"{term}"')
        url = ("https://opendata.paris.fr/api/explore/v2.1/catalog/datasets?limit=50"
               f"&where={where}&select=dataset_id,metas")
        try:
            results = json.loads(get(url)).get("results", [])
        except Exception as error:  # noqa: BLE001
            print(f"[{term}] erreur : {error!r}")
            continue
        for item in results:
            metas = item.get("metas", {}).get("default", {})
            seen[item["dataset_id"]] = (metas.get("title"), metas.get("records_count"), metas.get("modified"))
    for dataset_id, (title, count, modified) in sorted(seen.items()):
        print(f"{dataset_id} | {title} | {count} lignes | {modified}")
    for dataset_id in seen:
        url = (f"https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/{dataset_id}/records?limit=3"
               f"&where={urllib.parse.quote(chr(34) + 'grange aux belles' + chr(34))}")
        try:
            hits = json.loads(get(url)).get("results", [])
        except Exception:  # noqa: BLE001
            continue
        if hits:
            print(f"-> « grange aux belles » dans {dataset_id} : {json.dumps(hits[0], ensure_ascii=False)[:700]}")


def data_gouv():
    for term in ["établissements d'accueil du jeune enfant", "eaje", "crèches paris", "creches", "accueil petite enfance"]:
        url = "https://www.data.gouv.fr/api/1/datasets/?page_size=15&q=" + urllib.parse.quote(term)
        for item in json.loads(get(url)).get("data", []):
            organization = (item.get("organization") or {}).get("name")
            print(f"[{term}] {item['title']} | {organization} | {item['page']}")


def overpass():
    query = """
    [out:json][timeout:120];
    area(3600007444)->.paris;
    nwr["amenity"~"^(kindergarten|childcare)$"](area.paris);
    out tags center;
    """
    elements = json.loads(get("https://overpass-api.de/api/interpreter", data=urllib.parse.urlencode({"data": query}).encode(), timeout=180))["elements"]
    print("Éléments amenity=kindergarten|childcare dans Paris :", len(elements))
    named = [e for e in elements if e.get("tags", {}).get("name")]
    pattern = re.compile(r"crech|halte|multi.?accueil|jardin d.enfants|micro|garderie|babilou|people|chaperons|maison bleue|crechendo|evancia")
    creche_like = [e for e in named if pattern.search(fold(e["tags"]["name"])) or e["tags"].get("amenity") == "childcare"]
    print("Avec un nom :", len(named), "| ressemblant à une crèche ou childcare :", len(creche_like))
    for e in elements:
        tags = e.get("tags", {})
        if "grange" in fold(" ".join(tags.values())):
            print("-> GRANGE :", json.dumps(tags, ensure_ascii=False))
    for e in creche_like[:15]:
        print("   ", json.dumps(e["tags"], ensure_ascii=False)[:250])


def paris_fr():
    html = get("https://www.paris.fr/lieux/creche-municipale-grange-aux-belles-hopital-saint-louis-19903")
    title = re.search(r"<title>(.*?)</title>", html, re.S)
    print("Titre :", title.group(1).strip() if title else None)
    for needle in ["latitude", "longitude", "lat", "lng", "GeoCoordinates", "streetAddress", "postalCode", "data-address", "75010"]:
        for match in list(re.finditer(needle, html))[:2]:
            print(f"[{needle}]", html[max(0, match.start() - 120):match.end() + 160].replace("\n", " "))
    links = sorted(set(re.findall(r'href="(/[^"]*lieux[^"]*)"', html)))
    print("Liens /lieux :", links[:30])
    for sitemap in ["https://www.paris.fr/sitemap.xml", "https://www.paris.fr/robots.txt"]:
        try:
            text = get(sitemap)
            print(sitemap, len(text), text[:1500])
        except Exception as error:  # noqa: BLE001
            print(sitemap, "erreur", repr(error))


def apur():
    base = "https://carto2.apur.org/apur/rest/services/OPENDATA/EQUIPEMENT_PONCTUEL/MapServer"
    info = json.loads(get(base + "?f=json"))
    for layer in info.get("layers", []):
        print(f"Couche {layer['id']} : {layer['name']}")
    params = {"where": "c_cainsee >= 75101 AND c_cainsee <= 75120", "outFields": "*", "f": "json",
              "returnGeometry": "false", "resultRecordCount": 3000}
    features = json.loads(get(base + "/2/query?" + urllib.parse.urlencode(params)))["features"]
    print("Couche 2, Paris :", len(features))
    from collections import Counter
    print("c_niv3 :", Counter(f["attributes"].get("c_niv3") for f in features).most_common())
    print("c_gestion :", Counter(f["attributes"].get("c_gestion") for f in features).most_common())
    for f in features:
        blob = fold(" ".join(str(v) for v in f["attributes"].values()))
        if "vellefaux" in blob or "saint louis" in blob or "grange-aux" in blob:
            print("-> VELLEFAUX / SAINT-LOUIS :", json.dumps(f["attributes"], ensure_ascii=False)[:500])
        if "grange" in blob:
            print("-> GRANGE :", json.dumps(f["attributes"], ensure_ascii=False)[:600])
    print("Exemple de champs :", json.dumps(features[0]["attributes"], ensure_ascii=False)[:800])


if __name__ == "__main__":
    section("Paris Data (opendata.paris.fr)", paris_data)
    section("data.gouv.fr", data_gouv)
    section("OpenStreetMap (Overpass)", overpass)
    section("paris.fr (fiche Grange aux Belles)", paris_fr)
    section("Apur", apur)
