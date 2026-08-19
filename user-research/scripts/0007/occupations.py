#!/usr/bin/env python3
"""Fetch every occupation (P106) for the measured painters.

Wikidata lists Jim Carrey, George W. Bush and a serial killer as painters, and
pageview rank puts them near the top. Occupation is the structured, reproducible
way to drop them — the alternative is my opinion about 800 names.
"""
import json, os, sys, time, urllib.request
from collections import defaultdict
S = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Tondo/1.0 (daily-art app research; dhanesh.n.m19@gmail.com)"}
rows = json.load(open(os.path.join(S, "pageviews.json")))
qids = [r["qid"] for r in rows]
occ = {}
for i in range(0, len(qids), 50):
    batch = qids[i:i + 50]
    url = (f"https://www.wikidata.org/w/api.php?action=wbgetentities&ids={'|'.join(batch)}"
           f"&props=claims&format=json")
    data = {}
    for a in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45) as r:
                data = json.load(r)["entities"]; break
        except Exception:
            time.sleep(2 * (a + 1))
    for q, e in data.items():
        ids = []
        for c in e.get("claims", {}).get("P106", []):
            try: ids.append(c["mainsnak"]["datavalue"]["value"]["id"])
            except Exception: pass
        occ[q] = ids
    print(f"  {min(i+50, len(qids))}/{len(qids)}", flush=True)
    time.sleep(0.3)
json.dump(occ, open(os.path.join(S, "occupations.json"), "w"))
print(f"wrote occupations for {len(occ)} people")
