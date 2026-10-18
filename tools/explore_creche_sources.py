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
    import urllib.error
    urls = [
        "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets?limit=50&where=" + urllib.parse.quote('"creche"'),
        "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets?limit=50&where=" + urllib.parse.quote("search(\"creche\")"),
        "https://opendata.paris.fr/api/v2/catalog/datasets?rows=50&search=creche",
        "https://opendata.paris.fr/api/datasets/1.0/search/?rows=50&q=creche",
        "https://opendata.paris.fr/api/datasets/1.0/search/?rows=50&q=petite+enfance",
        "https://opendata.paris.fr/api/datasets/1.0/search/?rows=50&q=equipements",
    ]
    for url in urls:
        try:
            body = get(url)
        except urllib.error.HTTPError as error:
            print("HTTP", error.code, url, error.read()[:300])
            continue
        data = json.loads(body)
        items = data.get("results") or data.get("datasets") or []
        print("OK", url, len(items))
        for item in items:
            dataset = item.get("dataset", item)
            metas = dataset.get("metas", {})
            metas = metas.get("default", metas)
            print("   ", dataset.get("dataset_id") or dataset.get("datasetid"), "|", metas.get("title"), "|", metas.get("records_count"))


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


def strip_tags(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html)).strip()


def gunzip_get(url):
    import gzip
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    raw = urllib.request.urlopen(req, timeout=120).read()
    try:
        raw = gzip.decompress(raw)
    except OSError:
        pass
    return raw.decode("utf-8", "replace")


def paris_fr():
    from collections import Counter
    index = gunzip_get("https://www.paris.fr/sitemap.xml.gz")
    sitemaps = re.findall(r"<loc>(.*?)</loc>", index)
    print("Sitemaps :", sitemaps)
    lieux = []
    for sitemap in sitemaps:
        locs = re.findall(r"<loc>(.*?)</loc>", gunzip_get(sitemap))
        here = [u for u in locs if "/lieux/" in u]
        print(f"  {sitemap} : {len(locs)} URL dont {len(here)} lieux")
        lieux += here
    slugs = [u.split("/lieux/")[1] for u in lieux]
    prefixes = Counter("-".join(slug.split("-")[:2]) for slug in slugs)
    print("Préfixes de lieux :", prefixes.most_common(60))
    petite = [u for u in lieux if re.search(r"/lieux/(creche|halte|jardin-d-enfant|jardin-maternel|multi-accueil|micro-creche|etablissement-multi|eaje)", u)]
    print("Lieux petite enfance :", len(petite))
    print(Counter("-".join(u.split("/lieux/")[1].split("-")[:2]) for u in petite).most_common(30))
    print([u for u in petite if "grange" in u])
    samples = [u for u in petite if "grange-aux-belles" in u][:1]
    samples += [u for u in petite if "/creche-associative" in u][:1]
    samples += [u for u in petite if "/halte" in u][:1]
    samples += [u for u in petite if "/jardin" in u][:1]
    for url in samples:
        html = get(url)
        title = re.search(r'property="og:title" content="([^"]*)"', html)
        print("\n---", url, "|", title.group(1) if title else None)
        for block in re.findall(r'<div class="sidebar-section-content">(.*?)</div>', html, re.S)[:6]:
            print("   [sidebar]", strip_tags(block)[:300])
        coords = re.search(r"[?&;]c=([0-9.]+),([0-9.]+)", html)
        print("   coords :", coords.groups() if coords else None)
        for match in list(re.finditer(r"750\d\d", html))[:3]:
            print("   [750xx]", strip_tags(html[max(0, match.start() - 250):match.end() + 80]))


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
    section("paris.fr (fiche Grange aux Belles)", paris_fr)
