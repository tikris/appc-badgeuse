#!/usr/bin/env python3
"""Construit la liste des crèches de Paris embarquée dans l'application.

Source : Apur (Atelier parisien d'urbanisme), couche open data « Équipements ponctuels –
Petite enfance ». Les adresses sont normalisées (accents, libellés) avec l'API Adresse
de l'État (BAN). Exécuté par le workflow « Données crèches » (accès réseau requis).

Usage : python3 tools/fetch_creches.py [fichier de sortie]
"""
import csv
import datetime
import io
import json
import re
import sys
import unicodedata
import urllib.parse
import urllib.request
import uuid
from collections import Counter
from pathlib import Path

LAYER = "https://carto2.apur.org/apur/rest/services/OPENDATA/EQUIPEMENT_PONCTUEL/MapServer/2"
BAN_CSV = "https://api-adresse.data.gouv.fr/search/csv/"
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


def request(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT, **(headers or {})})
    with urllib.request.urlopen(req, timeout=180) as response:
        return response.read()


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
    words = [w for w in re.split(r"[\s']+", fold(name)) if w]
    return all(w in GENERIC_WORDS or w == "d" for w in words)


def normalize_addresses(rows):
    """Géocodage par lot (BAN) : renvoie {id: (numéro + voie, code postal)} pour les bons scores."""
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
        if score >= 0.7 and line.get("result_type") == "housenumber":
            result[line["id"]] = (f"{line['result_housenumber']} {line['result_street'] or line['result_name']}".strip()
                                  if line.get("result_street") else line["result_name"], line["result_postcode"])
    return result


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else OUTPUT
    params = {"where": "c_cainsee >= 75101 AND c_cainsee <= 75120", "outFields": "*", "outSR": "4326",
              "f": "geojson", "resultRecordCount": 3000}
    features = json.loads(request(LAYER + "/query?" + urllib.parse.urlencode(params)))["features"]
    print("Établissements reçus (Paris) :", len(features))
    print("Nomenclature :", Counter((f["properties"]["c_niv3"], kind_of(f["properties"]["l_ep_min"] or "")) for f in features))

    rows = []
    for feature in features:
        p = feature["properties"]
        name = (p.get("l_ep_min") or p.get("l_ep_maj") or "").strip()
        if not name or re.search(r"\bpmi\b|protection maternelle", fold(name)):
            continue
        lon, lat = feature["geometry"]["coordinates"]
        rows.append({
            "id": str(p["n_sq_ep"]),
            "source_name": name,
            "raw_address": raw_street(p),
            "citycode": str(p["c_cainsee"]),
            "postcode": f"{int(p['c_postal']):05d}" if p.get("c_postal") else "",
            "management": MANAGEMENT.get(str(p.get("c_gestion") or "").strip().upper()),
            "lat": round(lat, 6),
            "lon": round(lon, 6),
        })

    try:
        normalized = normalize_addresses(rows)
    except Exception as error:  # noqa: BLE001
        print("BAN indisponible, adresses brutes conservées :", error)
        normalized = {}
    print(f"Adresses normalisées par la BAN : {len(normalized)}/{len(rows)}")

    creches = []
    for row in rows:
        street, postcode = normalized.get(row["id"], (row["raw_address"], row["postcode"]))
        kind = kind_of(row["source_name"])
        name = row["source_name"]
        if is_generic(name):
            street_name = re.sub(r"^\d+\s*(bis|ter|quater)?\s*", "", street).strip()
            name = f"{kind} {street_name[:1].lower()}{street_name[1:]}" if street_name else kind
        creches.append({
            "id": row["id"], "name": name, "kind": kind, "management": row["management"],
            "street": street, "postcode": postcode or row["postcode"], "lat": row["lat"], "lon": row["lon"],
        })
    creches.sort(key=lambda c: (c["postcode"], fold(c["name"])))

    document = {
        "source": "Apur – Équipements ponctuels « Petite enfance » (opendata.apur.org), adresses normalisées avec l'API Adresse (BAN)",
        "licence": "ODbL (Open Database License) pour les données Apur ; adresses : Base Adresse Nationale, Licence Ouverte",
        "generated": datetime.date.today().isoformat(),
        "creches": creches,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(creches)} crèches écrites dans {output} ({output.stat().st_size // 1024} Ko)")
    print("Licence :", document["licence"])
    print("Types :", Counter(c["kind"] for c in creches))
    print("Gestion :", Counter(c["management"] for c in creches))
    print("Exemples :")
    for creche in creches[::max(1, len(creches) // 12)]:
        print("  ", json.dumps(creche, ensure_ascii=False))


if __name__ == "__main__":
    main()
