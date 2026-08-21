#!/usr/bin/env python3
"""Fetch theme candidates from Wikidata for the three axes (0008 research).

Axes and their Wikidata classes (resolved live via wbsearchentities, 2026-08-20):
  movement : instances of Q968159  (art movement)
  genre    : instances of Q1792379 (art genre)
  medium   : instances of Q1231896 (painting technique) or Q3300034 (painting material)

Each candidate: qid, label, description, sitelinks, enwiki title. Sitelinks are the
notability prior (0007's method) that decides who is worth a pageview call.

Output: user-research/data/0008-candidates.json
"""
import json, sys, time, urllib.parse, urllib.request

UA = {"User-Agent": "TondoResearch/0.1 (dhanesh.n.m19@gmail.com)"}
ENDPOINT = "https://query.wikidata.org/sparql"

QUERY = """
SELECT ?item ?itemLabel ?itemDescription ?sitelinks ?article WHERE {
  %s
  ?item wikibase:sitelinks ?sitelinks .
  ?article schema:about ?item ;
           schema:isPartOf <https://en.wikipedia.org/> .
  FILTER(?sitelinks >= 5)
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
"""

AXES = {
    "movement": "?item wdt:P31 wd:Q968159 .",
    "genre": "?item wdt:P31 wd:Q1792379 .",
    "medium": "{ ?item wdt:P31 wd:Q1231896 . } UNION { ?item wdt:P31 wd:Q3300034 . }",
}


def sparql(where):
    q = QUERY % where
    url = ENDPOINT + "?" + urllib.parse.urlencode({"format": "json", "query": q})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
                return json.load(r)["results"]["bindings"]
        except Exception as e:
            print(f"  attempt {attempt+1} failed: {e}", file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    raise SystemExit("SPARQL failed after 3 attempts")


def main():
    out = {}
    for axis, where in AXES.items():
        rows = sparql(where)
        seen = {}
        for b in rows:
            qid = b["item"]["value"].rsplit("/", 1)[-1]
            title = urllib.parse.unquote(b["article"]["value"].rsplit("/wiki/", 1)[-1])
            rec = {
                "qid": qid,
                "label": b.get("itemLabel", {}).get("value", ""),
                "description": b.get("itemDescription", {}).get("value", ""),
                "sitelinks": int(b["sitelinks"]["value"]),
                "wikipedia_title": title,
            }
            # dedupe on qid, keep max sitelinks
            if qid not in seen or rec["sitelinks"] > seen[qid]["sitelinks"]:
                seen[qid] = rec
        ranked = sorted(seen.values(), key=lambda r: -r["sitelinks"])
        out[axis] = ranked
        print(f"{axis}: {len(ranked)} candidates with enwiki article (sitelinks>=5)")
        time.sleep(2)

    path = "user-research/data/0008-candidates.json"
    with open(path, "w") as f:
        json.dump({"generated_on": "2026-08-20", "classes": AXES, "candidates": out}, f, indent=1)
    print("wrote", path)


if __name__ == "__main__":
    main()
