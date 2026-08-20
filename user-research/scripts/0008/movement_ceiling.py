#!/usr/bin/env python3
"""Estimate the movement facet's pool ceiling via artist P135 (0008 research).

The 0022 dry run measured Route 1 (P135 through the 0019 QID list) at 124/2000
works and stopped — reconciling the pool's other ~775 artist strings was "a
research project the size of the 0007 list." This script measures a SAMPLE of
that unreconciled space to bound the ceiling: the top pool artist strings by
work count (placeholders excluded via the app's own NOT_AN_ARTIST shape),
resolved name -> QID via wbsearchentities, then one batched SPARQL for P135.

Output is an estimate with its sample frame stated, not a reconciliation:
wbsearchentities' first hit is not the 0019 collision-aware matcher, and a
wrong first hit inflates or deflates a movement. Per-artist rows are kept in
the data file so every resolution can be re-adjudicated.

Output: user-research/data/0008-movement-ceiling.json
"""
import json, re, time, urllib.parse, urllib.request
from collections import Counter

UA = {"User-Agent": "TondoResearch/0.1 (dhanesh.n.m19@gmail.com)"}
SAMPLE_SIZE = 80

# Placeholder shapes, mirroring app/models/painting.rb NOT_AN_ARTIST without
# importing Ruby: exact-word placeholders + region-with-parenthetical +
# school/workshop/painter-of-a-country forms.
PLACEHOLDER_RX = re.compile(
    r"^(unidentified|unknown|anonymous|various)|"
    r"^(china|japan|islamic|tibet|india|korea|nepal|egypt|italy|ethiopia|sweden|"
    r"united states|mughal|italian|french|german|spanish|dutch|flemish|british|"
    r"english|austrian|teotihuacan|chancay|gujarati)\b|"
    r"school\b|workshop|painter$|\)$",
    re.IGNORECASE)


def get(url, timeout=30):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
                return json.load(r)
        except Exception:
            time.sleep(2 * (attempt + 1))
    return None


def main():
    works = json.load(open("db/seeds/paintings.json"))
    by_artist = Counter()
    for w in works:
        a = (w.get("artist") or "").strip()
        if a and not PLACEHOLDER_RX.search(a):
            by_artist[a] += 1
    total_attributed = sum(by_artist.values())
    sample = by_artist.most_common(SAMPLE_SIZE)
    print(f"{len(by_artist)} attributed artist strings covering {total_attributed} works; "
          f"sampling top {SAMPLE_SIZE} ({sum(n for _, n in sample)} works)")

    rows = []
    for name, nworks in sample:
        # strip museum parentheticals the way 0007 learned to
        clean = re.sub(r"\s*\(.*?\)\s*", " ", name).strip()
        url = ("https://www.wikidata.org/w/api.php?action=wbsearchentities&format=json"
               "&language=en&type=item&limit=1&search=" + urllib.parse.quote(clean))
        d = get(url)
        hit = (d or {}).get("search", [])
        rows.append({"artist": name, "works": nworks,
                     "qid": hit[0]["id"] if hit else None,
                     "matched_label": hit[0].get("label") if hit else None,
                     "matched_description": hit[0].get("description", "") if hit else None})
        time.sleep(0.3)

    qids = [r["qid"] for r in rows if r["qid"]]
    values = " ".join(f"wd:{q}" for q in qids)
    query = f"""SELECT ?item ?movement ?movementLabel WHERE {{
      VALUES ?item {{ {values} }}
      ?item wdt:P135 ?movement .
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}"""
    url = ("https://query.wikidata.org/sparql?" +
           urllib.parse.urlencode({"format": "json", "query": query}))
    d = get(url, timeout=90)
    p135 = {}
    for b in (d or {}).get("results", {}).get("bindings", []):
        q = b["item"]["value"].rsplit("/", 1)[-1]
        p135.setdefault(q, []).append(b["movementLabel"]["value"])

    movement_works = Counter()
    with_movement = 0
    for r in rows:
        r["movements"] = p135.get(r["qid"], [])
        if r["movements"]:
            with_movement += r["works"]
            for m in r["movements"]:
                movement_works[m] += r["works"]

    sampled_works = sum(r["works"] for r in rows)
    out = {
        "generated_on": "2026-08-20",
        "sample_frame": f"top {SAMPLE_SIZE} attributed artist strings by work count",
        "attributed_artist_strings": len(by_artist),
        "attributed_works": total_attributed,
        "sampled_works": sampled_works,
        "sampled_works_with_p135_artist": with_movement,
        "p135_rate_in_sample": round(with_movement / sampled_works, 3),
        "movement_work_counts_in_sample": dict(movement_works.most_common()),
        "artists": rows,
    }
    with open("user-research/data/0008-movement-ceiling.json", "w") as f:
        json.dump(out, f, indent=1)
    print(f"sampled works {sampled_works}, with-P135 {with_movement} "
          f"({out['p135_rate_in_sample']:.1%})")
    print("top movements:", dict(movement_works.most_common(12)))


if __name__ == "__main__":
    main()
