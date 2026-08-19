#!/usr/bin/env python3
"""Fetch complete English aliases for the final list.

The bulk SPARQL alias dump came back truncated — 37,059 of 65,626 painters, and
missing exactly the famous ones (van Gogh, Leonardo, Velázquez had none). Aliases
are load-bearing: they are the difference between finding 0 Goya works and 29.
200 names is four API calls, so it is fetched directly rather than trusted.
"""
import json, os, time, urllib.request
S = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Tondo/1.0 (daily-art app research; dhanesh.n.m19@gmail.com)"}
doc = json.load(open(os.path.join(S, "recognizable-names.json")))
qids = [n["qid"] for n in doc["names"]]
got = {}
for i in range(0, len(qids), 50):
    batch = qids[i:i + 50]
    url = (f"https://www.wikidata.org/w/api.php?action=wbgetentities&ids={'|'.join(batch)}"
           f"&props=aliases|labels&languages=en&format=json")
    for a in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45) as r:
                ents = json.load(r)["entities"]
            break
        except Exception:
            time.sleep(2 * (a + 1)); ents = {}
    for q, e in ents.items():
        al = [x["value"] for x in e.get("aliases", {}).get("en", [])]
        lab = e.get("labels", {}).get("en", {}).get("value")
        got[q] = (lab, al)
    time.sleep(0.3)

fixed = 0
for n in doc["names"]:
    lab, al = got.get(n["qid"], (None, []))
    merged = sorted({*(n.get("aliases") or []), *al}, key=lambda s: (len(s), s))
    if len(merged) > len(n.get("aliases") or []): fixed += 1
    n["aliases"] = merged[:30]
json.dump(doc, open(os.path.join(S, "recognizable-names.json"), "w"), ensure_ascii=False, indent=2)
empty = [n["name"] for n in doc["names"] if not n["aliases"]]
print(f"aliases filled for {fixed} names; {len(empty)} still have none")
print("  no aliases:", ", ".join(empty[:15]))
