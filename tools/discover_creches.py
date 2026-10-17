#!/usr/bin/env python3
"""Découverte (CI) : cherche les jeux de données « crèches / petite enfance » de Paris."""
import json
import urllib.parse
import urllib.request

PORTALS = ["https://opendata.paris.fr", "https://dashboard.paris", "https://data.iledefrance.fr"]
QUERIES = ["creche", "crèches", "petite enfance", "accueil du jeune enfant", "EAJE"]


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "appc-badgeuse"}), timeout=30) as response:
        return json.load(response)


for portal in PORTALS:
    seen = set()
    for query in QUERIES:
        url = f"{portal}/api/explore/v2.1/catalog/datasets?" + urllib.parse.urlencode(
            {"where": f'search("{query}")', "limit": 20}
        )
        try:
            data = get(url)
        except Exception as error:  # noqa: BLE001
            print(portal, query, "ERREUR", error)
            continue
        for dataset in data.get("results", []):
            dataset_id = dataset["dataset_id"]
            if dataset_id in seen:
                continue
            seen.add(dataset_id)
            metas = dataset.get("metas", {}).get("default", {})
            title = metas.get("title", "")
            if not any(k in (title + dataset_id).lower() for k in ["crèche", "creche", "enfance", "eaje", "garderie"]):
                continue
            fields = [f["name"] for f in dataset.get("fields", [])]
            print(f"\n=== {portal} :: {dataset_id} :: {title} :: {metas.get('records_count')} :: {metas.get('license')}")
            print("champs :", fields)
            try:
                sample = get(f"{portal}/api/explore/v2.1/catalog/datasets/{dataset_id}/records?limit=2")
                for record in sample.get("results", []):
                    print(json.dumps(record, ensure_ascii=False)[:700])
            except Exception as error:  # noqa: BLE001
                print("  échantillon ERREUR", error)
