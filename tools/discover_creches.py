#!/usr/bin/env python3
"""Découverte (CI) : sources open data listant les crèches de Paris."""
import csv
import io
import json
import urllib.parse
import urllib.request


def get(url, raw=False):
    request = urllib.request.Request(url, headers={"User-Agent": "appc-badgeuse"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read() if raw else json.load(response)


def show(title, value):
    print(f"\n=== {title}\n{value}")


# 1. data.gouv.fr : recherche
for query in ["crèches paris", "établissements d'accueil du jeune enfant", "EAJE", "accueil petite enfance paris"]:
    try:
        data = get("https://www.data.gouv.fr/api/1/datasets/?" + urllib.parse.urlencode({"q": query, "page_size": 8}))
        show(f"data.gouv.fr « {query} »", "\n".join(
            f"- {d['slug']} | {d['title']} | {(d.get('organization') or {}).get('name')} | {d.get('license')}"
            for d in data["data"]))
    except Exception as error:  # noqa: BLE001
        show(f"data.gouv.fr « {query} »", f"ERREUR {error}")

# 2. Jeux candidats : ressources + aperçu des CSV
for slug in ["poi-eaje-3", "etablissements-daccueil-de-la-petite-enfance-pe"]:
    try:
        dataset = get(f"https://www.data.gouv.fr/api/1/datasets/{slug}/")
        show(f"{slug} : {dataset['title']} ({dataset.get('license')}, maj {dataset.get('last_modified')})", "")
        for resource in dataset["resources"][:6]:
            print(f"- {resource['title']} | {resource.get('format')} | {resource.get('filesize')} | {resource['url']}")
        for resource in dataset["resources"][:3]:
            if (resource.get("format") or "").lower() not in ("csv", "json", "geojson"):
                continue
            body = get(resource["url"], raw=True)
            text = body.decode("utf-8-sig", errors="replace")
            if resource["format"].lower() == "csv":
                dialect = csv.Sniffer().sniff(text[:5000], delimiters=";,")
                rows = list(csv.DictReader(io.StringIO(text), dialect=dialect))
                paris = [r for r in rows if any(str(v).startswith("75") and len(str(v)) == 5 for v in r.values())]
                print(f"  {resource['title']} : {len(rows)} lignes, {len(paris)} à Paris ; colonnes : {list(rows[0].keys()) if rows else []}")
                for row in paris[:3]:
                    print("  ", json.dumps(row, ensure_ascii=False)[:600])
            else:
                print("  ", text[:600])
    except Exception as error:  # noqa: BLE001
        show(slug, f"ERREUR {error}")
