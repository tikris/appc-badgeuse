#!/usr/bin/env python3
"""Construit la liste des crèches de Paris embarquée dans l'application.

Sources, par ordre de priorité (un établissement à moins de 60 m d'un autre déjà retenu est
considéré comme un doublon) :
1. Ville de Paris : annuaire des lieux de paris.fr (crèches municipales, associatives,
   familiales, parentales, haltes-garderies, jardins d'enfants…), avec les noms officiels ;
2. Apur, couche open data « Équipements ponctuels – Petite enfance » (ODbL) ;
3. OpenStreetMap (ODbL), surtout pour les crèches privées et micro-crèches.
Les adresses sont normalisées avec l'API Adresse de l'État (BAN).
Exécuté par le workflow « Données crèches » (accès réseau requis).

Usage : python3 tools/fetch_creches.py [fichier de sortie]
"""
import csv
import datetime
import gzip
import html
import io
import json
import math
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
import uuid
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

LAYER = "https://carto2.apur.org/apur/rest/services/OPENDATA/EQUIPEMENT_PONCTUEL/MapServer/2"
BAN_CSV = "https://api-adresse.data.gouv.fr/search/csv/"
BAN_REVERSE_CSV = "https://api-adresse.data.gouv.fr/reverse/csv/"
PARIS_SITEMAP = "https://cdn.paris.fr/paris/sitemaps/parisfr/lieux.xml.gz"
PARIS_PETITE_ENFANCE = re.compile(
    r"/lieux/(creche|halte|jardin-d-enfant|jardin-maternel|multi-accueil|micro-creche)[a-z0-9-]*-\d+$"
)
OVERPASS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]
DUPLICATE_METERS = 60
OUTPUT = Path(__file__).resolve().parent.parent / "App" / "BadgeCreche" / "Resources" / "creches-paris.json"
USER_AGENT = "appc-badgeuse (https://github.com/tikris/appc-badgeuse)"

DESIGNATIONS = {
    "RUE": "rue", "R": "rue", "AV": "avenue", "BD": "boulevard", "PL": "place", "ALL": "allée",
    "PAS": "passage", "QU": "quai", "QUAI": "quai", "IMP": "impasse", "SQ": "square", "VLA": "villa",
    "CITE": "cité", "CHE": "chemin", "RTE": "route", "SENT": "sentier", "PROM": "promenade",
    "CRS": "cours", "HAM": "hameau", "PTE": "porte", "CHAU": "chaussée", "ESPL": "esplanade",
    "GAL": "galerie", "PARV": "parvis", "RPT": "rond-point", "COUR": "cour", "PTR": "petite rue",
    "SENTE": "sente", "CAR": "carrefour", "PORT": "port", "JARD": "jardin", "PONT": "pont",
}
SUFFIXES = {"B": " bis", "T": " ter", "Q": " quater"}
GENERIC_WORDS = {
    "creche", "creches", "collective", "familiale", "municipale", "departementale", "parentale",
    "associative", "halte", "garderie", "halte-garderie", "multi", "accueil", "multi-accueil",
    "micro", "micro-creche", "mini", "mini-creche", "jardin", "d'enfants", "enfants", "de", "la",
    "et", "-", "municipal", "collectif", "familial", "eaje",
}
MANAGEMENT = {"M": "municipale", "A": "associative", "D": "départementale"}


def request(url, data=None, headers=None, attempts=3):
    for attempt in range(attempts):
        try:
            req = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT, **(headers or {})})
            with urllib.request.urlopen(req, timeout=180) as response:
                return response.read()
        except Exception:  # noqa: BLE001
            if attempt == attempts - 1:
                raise
            time.sleep(2 * (attempt + 1))


def fold(text):
    text = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in text if unicodedata.category(c) != "Mn")


def title_case(text):
    small = {"de", "du", "des", "la", "le", "les", "et", "sur", "aux", "au", "en", "d", "l"}
    words = []
    for index, word in enumerate(text.lower().split()):
        parts = [p.capitalize() if (index == 0 or p not in small) else p for p in word.split("-")]
        words.append("-".join(parts))
    return " ".join(words).replace("D'", "d'").replace("L'", "l'")


def raw_street(p):
    number = p.get("n_voie")
    suffix = SUFFIXES.get(str(p.get("c_suf1") or "").strip().upper(), "")
    designation = DESIGNATIONS.get(str(p.get("c_desi") or "").strip().upper(), str(p.get("c_desi") or "").lower())
    liaison = str(p.get("c_liaison") or "").strip().lower()
    liaison = "" if len(liaison) <= 1 and liaison != "d" else liaison
    name = title_case(str(p.get("l_voie") or ""))
    parts = [f"{number}{suffix}" if number else "", designation, liaison, name]
    return re.sub(r"\s+", " ", " ".join(x for x in parts if x)).replace("d ", "d'").strip()


def kind_of(name):
    n = fold(name)
    for needle, label in [
        ("halte", "Halte-garderie"), ("jardin d", "Jardin d'enfants"), ("multi", "Multi-accueil"),
        ("micro", "Micro-crèche"), ("mini", "Micro-crèche"), ("familial", "Crèche familiale"),
        ("parental", "Crèche parentale"), ("collecti", "Crèche collective"),
    ]:
        if needle in n:
            return label
    return "Crèche"


def is_generic(name):
    if re.search(r"etage|^\W*\d", fold(name)):
        return True
    words = [w for w in re.split(r"[\s']+", fold(name)) if w]
    return all(w in GENERIC_WORDS or w == "d" for w in words)


def management_of(text):
    t = fold(text)
    if "municipal" in t or "ville de paris" in t or "mairie de paris" in t:
        return "municipale"
    if "associati" in t or "parental" in t:
        return "associative"
    return None


def distance(a, b):
    p = math.pi / 180
    h = (math.sin((b["lat"] - a["lat"]) * p / 2) ** 2
         + math.cos(a["lat"] * p) * math.cos(b["lat"] * p) * math.sin((b["lon"] - a["lon"]) * p / 2) ** 2)
    return 2 * 6371000 * math.asin(math.sqrt(h))


def multipart(fields, csv_text):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"data\"; filename=\"data.csv\"\r\n"
            f"Content-Type: text/csv\r\n\r\n{csv_text}\r\n")
    for name, value in fields:
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n"
    body += f"--{boundary}--\r\n"
    return body.encode(), {"Content-Type": f"multipart/form-data; boundary={boundary}"}


def reverse_addresses(rows):
    """Géocodage inverse par lot (BAN) : {id: (numéro + voie, code postal)}."""
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["id", "lat", "lon"])
    for row in rows:
        writer.writerow([row["id"], row["lat"], row["lon"]])
    body, headers = multipart([], buffer.getvalue())
    response = request(BAN_REVERSE_CSV, data=body, headers=headers)
    result = {}
    for line in csv.DictReader(io.StringIO(response.decode("utf-8-sig"))):
        if line.get("result_type") == "housenumber" and line.get("result_postcode", "").startswith("75"):
            street = f"{line['result_housenumber']} {line.get('result_street') or line.get('result_name', '')}".strip()
            result[line["id"]] = (street, line["result_postcode"])
    return result


def normalize_addresses(rows):
    """Géocodage par lot (BAN) : {id: (numéro + voie, code postal, lat, lon)} pour les bons scores."""
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["id", "adresse", "citycode"])
    for row in rows:
        writer.writerow([row["id"], row["raw_address"], row["citycode"]])
    boundary = uuid.uuid4().hex
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"data\"; filename=\"creches.csv\"\r\n"
        f"Content-Type: text/csv\r\n\r\n{buffer.getvalue()}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"columns\"\r\n\r\nadresse\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"citycode\"\r\n\r\ncitycode\r\n"
        f"--{boundary}--\r\n"
    ).encode()
    response = request(BAN_CSV, data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    result = {}
    for line in csv.DictReader(io.StringIO(response.decode("utf-8-sig"))):
        try:
            score = float(line.get("result_score") or 0)
        except ValueError:
            score = 0
        if score >= 0.6 and line.get("result_type") == "housenumber":
            result[line["id"]] = (f"{line['result_housenumber']} {line['result_street'] or line['result_name']}".strip()
                                  if line.get("result_street") else line["result_name"], line["result_postcode"],
                                  float(line["latitude"]), float(line["longitude"]))
    return result


def paris_fr_rows():
    """Annuaire des lieux de paris.fr : nom officiel, adresse et coordonnées de chaque établissement."""
    xml = request(PARIS_SITEMAP)
    try:
        xml = gzip.decompress(xml)
    except OSError:
        pass
    urls = sorted({u for u in re.findall(r"<loc>(.*?)</loc>", xml.decode("utf-8", "replace"))
                   if PARIS_PETITE_ENFANCE.search(u)})
    print("paris.fr : lieux petite enfance dans le plan du site :", len(urls))

    def parse(url):
        try:
            page = request(url).decode("utf-8", "replace")
        except Exception as error:  # noqa: BLE001
            print("  page illisible :", url, error)
            return None
        title = re.search(r'property="og:title" content="([^"]*)"', page)
        block = re.search(r'<div class="sidebar-section-content">(.*?)</div>', page, re.S)
        coords = re.search(r"[?&;]c=([0-9.]+),([0-9.]+)", page)
        if not title or not block:
            print("  page sans nom ni adresse :", url)
            return None
        name = re.sub(r"\s+", " ", html.unescape(title.group(1))).strip()
        text = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", block.group(1)))).strip()
        address = text[len(name):] if text.startswith(name) else text
        address = address.strip(" ,")
        arrondissement = re.search(r"Paris\s*(\d{1,2})\s*(?:er|e|ème)\b", address)
        street = re.sub(r",?\s*Paris\s*\d{1,2}\s*(?:er|e|ème)\b.*$", "", address).strip(" ,")
        number = int(arrondissement.group(1)) if arrondissement else 0
        return {
            "id": "pf-" + url.rsplit("-", 1)[1],
            "source_name": name,
            "raw_address": street,
            "citycode": str(75100 + number) if 1 <= number <= 20 else "",
            "postcode": f"750{number:02d}" if 1 <= number <= 20 else "",
            "management": management_of(name + " " + url),
            # Coordonnées de la page : itinéraire GéoVélo, souvent décalé de 100 à 200 m de l'adresse.
            # Gardées seulement en secours si la BAN ne trouve pas l'adresse.
            "page_lat": round(float(coords.group(2)), 6) if coords else None,
            "page_lon": round(float(coords.group(1)), 6) if coords else None,
            "lat": None,
            "lon": None,
            "src": "paris.fr",
        }

    with ThreadPoolExecutor(max_workers=6) as pool:
        rows = [row for row in pool.map(parse, urls) if row and row["raw_address"]]
    print("paris.fr : établissements lus :", len(rows))
    return rows


def apur_rows():
    params = {"where": "c_cainsee >= 75101 AND c_cainsee <= 75120", "outFields": "*", "outSR": "4326",
              "f": "geojson", "resultRecordCount": 3000}
    features = json.loads(request(LAYER + "/query?" + urllib.parse.urlencode(params)))["features"]
    print("Apur : établissements reçus :", len(features))
    rows = []
    for feature in features:
        p = feature["properties"]
        name = (p.get("l_ep_min") or p.get("l_ep_maj") or "").strip()
        if not name or re.search(r"\bpmi\b|protection maternelle", fold(name)):
            continue
        lon, lat = feature["geometry"]["coordinates"]
        rows.append({
            "id": "apur-" + str(p["n_sq_ep"]),
            "source_name": name,
            "raw_address": raw_street(p),
            "citycode": str(p["c_cainsee"]),
            "postcode": f"{int(p['c_postal']):05d}" if p.get("c_postal") else "",
            "management": MANAGEMENT.get(str(p.get("c_gestion") or "").strip().upper()),
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "src": "apur",
        })
    return rows


def osm_rows():
    query = """[out:json][timeout:180];
    area(3600007444)->.paris;
    nwr["amenity"~"^(kindergarten|childcare)$"]["name"](area.paris);
    out tags center;"""
    elements = None
    for server in OVERPASS:
        try:
            elements = json.loads(request(server, data=urllib.parse.urlencode({"data": query}).encode()))["elements"]
            break
        except Exception as error:  # noqa: BLE001
            print("Overpass indisponible :", server, error)
    if elements is None:
        return []
    looks_like_creche = re.compile(r"cr[eè]che|creche|halte|multi.?accueil|micro|jardin d.enfants|babilou|people.?&?.?baby"
                                   r"|chaperons|maison bleue|cr[eé]chendo|evancia|grandir|tom ?pouce")
    excluded = re.compile(r"maternelle|ecole|elementaire|loisirs|periscolaire|ludotheque|assistante|\bmam\b|\bram\b|relais"
                          # agences de garde à domicile, qui ne sont pas des crèches
                          r"|kinougarde|family ?sphere|babychou|kangourou kids|yoopies|babysits|o2 |nounou|garde a domicile")
    rows = []
    for e in elements:
        tags = e.get("tags", {})
        name = tags["name"].strip()
        folded = fold(name)
        kind_fr = tags.get("kindergarten:FR", "")
        if excluded.search(folded) and not looks_like_creche.search(folded):
            continue
        if not (tags["amenity"] == "childcare" or "crèche" in kind_fr or "halte" in kind_fr or looks_like_creche.search(folded)):
            continue
        lat = e.get("lat") or (e.get("center") or {}).get("lat")
        lon = e.get("lon") or (e.get("center") or {}).get("lon")
        if lat is None:
            continue
        number, street = tags.get("addr:housenumber"), tags.get("addr:street")
        operator = " ".join(tags.get(k, "") for k in ("operator", "brand", "operator:type"))
        management = management_of(operator)
        if management is None and (tags.get("brand") or "private" in tags.get("operator:type", "")):
            management = "privée"
        rows.append({
            "id": f"osm-{e['type'][0]}{e['id']}",
            "source_name": name,
            "raw_address": f"{number} {street}" if number and street else "",
            "citycode": "",
            "postcode": tags.get("addr:postcode", ""),
            "management": management,
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "src": "osm",
        })
    print("OpenStreetMap : établissements retenus :", len(rows), "sur", len(elements))
    return rows


def significant_words(name):
    return {w for w in re.split(r"[^a-z0-9]+", fold(name)) if len(w) > 2 and w not in GENERIC_WORDS}


def merge(sources):
    """Garde la première source pour chaque établissement : les suivantes ne complètent que les manques
    (doublon : même adresse, moins de 60 m, ou moins de 150 m avec un nom en commun)."""
    kept = []
    for label, rows in sources:
        previous = list(kept)  # pas de dédoublonnage à l'intérieur d'une même source
        added = 0
        for row in rows:
            if row["lat"] is None:
                continue
            row["words"] = significant_words(row["source_name"])
            row["address_key"] = (fold(row["street"]).replace("-", " "), row["postcode"])
            duplicate = any(
                row["address_key"] == other["address_key"]
                or (d := distance(row, other)) < DUPLICATE_METERS
                or (d < 150 and row["words"] & other["words"])
                for other in previous
            )
            if not duplicate:
                kept.append(row)
                added += 1
        print(f"Fusion : {label} apporte {added} établissement(s) sur {len(rows)}")
    return kept


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else OUTPUT
    paris = paris_fr_rows()
    try:
        apur = apur_rows()
    except Exception as error:  # noqa: BLE001
        print("Apur indisponible :", error)
        apur = []
    osm = osm_rows()

    # Adresses normalisées et coordonnées du point d'adresse (BAN) pour paris.fr et l'Apur.
    try:
        normalized = normalize_addresses([r for r in paris + apur if r["raw_address"] and r["citycode"]])
    except Exception as error:  # noqa: BLE001
        print("BAN indisponible, adresses brutes conservées :", error)
        normalized = {}
    fallback = 0
    for row in paris + apur:
        if row["id"] in normalized:
            row["street"], row["postcode"], lat, lon = normalized[row["id"]]
            if row["src"] == "paris.fr":
                row["lat"], row["lon"] = round(lat, 6), round(lon, 6)
        else:
            row["street"] = row["raw_address"]
            if row["src"] == "paris.fr":
                row["lat"], row["lon"] = row["page_lat"], row["page_lon"]
                fallback += 1
    print(f"BAN : {len(normalized)} adresses normalisées ; paris.fr sans adresse reconnue (coordonnées de la page) : {fallback}")

    # OpenStreetMap : adresse des tags, sinon géocodage inverse.
    try:
        reversed_ = reverse_addresses([r for r in osm if not (r["raw_address"] and r["postcode"])])
    except Exception as error:  # noqa: BLE001
        print("BAN (inverse) indisponible :", error)
        reversed_ = {}
    for row in osm:
        if row["raw_address"] and row["postcode"]:
            row["street"] = row["raw_address"]
        elif row["id"] in reversed_:
            row["street"], row["postcode"] = reversed_[row["id"]]
        else:
            row["street"] = ""
    print(f"OpenStreetMap : {len(reversed_)} adresses retrouvées par géocodage inverse")

    rows = merge([("paris.fr", paris), ("Apur", apur), ("OpenStreetMap", osm)])

    creches = []
    for row in rows:
        street, postcode = row["street"], row["postcode"]
        if not street or not postcode.startswith("75"):
            continue
        kind = kind_of(row["source_name"])
        name = row["source_name"]
        if is_generic(name):
            street_name = re.sub(r"^\d+\s*(bis|ter|quater)?\s*", "", street).strip()
            name = f"{kind} {street_name[:1].lower()}{street_name[1:]}" if street_name else kind
        creches.append({
            "id": row["id"], "name": name, "kind": kind, "management": row["management"],
            "street": street, "postcode": postcode, "lat": row["lat"], "lon": row["lon"], "src": row["src"],
        })
    creches.sort(key=lambda c: (c["postcode"], fold(c["name"])))

    document = {
        "source": "Ville de Paris (annuaire des lieux de paris.fr), Apur (« Équipements ponctuels – Petite enfance »), "
                  "OpenStreetMap ; adresses normalisées avec l'API Adresse (BAN)",
        "licence": "ODbL (Open Database License) : données Apur et © contributeurs OpenStreetMap ; "
                   "informations publiques de la Ville de Paris ; adresses : Base Adresse Nationale, Licence Ouverte",
        "generated": datetime.date.today().isoformat(),
        "creches": creches,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(creches)} établissements écrits dans {output} ({output.stat().st_size // 1024} Ko)")
    print("Sources :", Counter(c["src"] for c in creches))
    print("Types :", Counter(c["kind"] for c in creches))
    print("Gestion :", Counter(c["management"] for c in creches))
    print("Contrôle « Grange aux Belles » :", [c for c in creches if "grange aux belles" in fold(c["name"] + " " + c["street"]).replace("-", " ")])
    print("Exemples :")
    for creche in creches[::max(1, len(creches) // 15)]:
        print("  ", json.dumps(creche, ensure_ascii=False))


if __name__ == "__main__":
    main()
