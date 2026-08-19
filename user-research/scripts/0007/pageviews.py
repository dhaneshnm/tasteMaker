#!/usr/bin/env python3
"""English-Wikipedia pageviews for the most-linked painters in the dictionary.

This is the RECOGNITION instrument: how many people actually look an artist up.
Reddit mention frequency is the independent second instrument, and the two are
reported side by side and never averaged.
"""
import json, os, sys, time, urllib.parse, urllib.request
from collections import defaultdict

S = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Tondo/1.0 (daily-art app research; dhanesh.n.m19@gmail.com)"}
API = ("https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/en.wikipedia/"
       "all-access/user/{}/monthly/2025080100/2026080100")
TOP = int(sys.argv[1] if len(sys.argv) > 1 else 700)
OUT = os.path.join(S, "pageviews.json")

painters = {}
for line in open(os.path.join(S, "raw_core.jsonl")):
    try: r = json.loads(line)
    except Exception: continue
    qid = r["item"].rsplit("/", 1)[-1]
    art = r.get("article") or ""
    if not art: continue
    title = urllib.parse.unquote(art.rsplit("/", 1)[-1])
    prev = painters.get(qid)
    sl = int(r.get("sitelinks") or 0)
    # Wikidata emits a genid URL for "value unknown"; only a real timestamp parses.
    def year(v):
        v = (v or "").lstrip("+")
        return int(v[:4]) if v[:4].isdigit() else None
    if prev is None or sl > prev["sitelinks"]:
        painters[qid] = {"qid": qid, "name": r.get("label") or title.replace("_", " "),
                         "title": title, "sitelinks": sl,
                         "born": year(r.get("birth")), "died": year(r.get("death"))}

aliases = defaultdict(list)
for line in open(os.path.join(S, "raw_alias.jsonl")):
    try: r = json.loads(line)
    except Exception: continue
    aliases[r["item"].rsplit("/", 1)[-1]].append(r["alias"])

ranked = sorted(painters.values(), key=lambda p: -p["sitelinks"])[:TOP]
print(f"{len(painters)} painters in dictionary; measuring top {len(ranked)} by sitelinks", flush=True)

done = {}
if os.path.exists(OUT):
    done = {r["qid"]: r for r in json.load(open(OUT))}

out = []
for i, p in enumerate(ranked):
    if p["qid"] in done and done[p["qid"]].get("pageviews_12mo") is not None:
        out.append(done[p["qid"]]); continue
    url = API.format(urllib.parse.quote(p["title"].replace(" ", "_"), safe=""))
    views = None
    for a in range(2):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=25) as r:
                views = sum(x["views"] for x in json.load(r)["items"])
            break
        except Exception:
            time.sleep(1.0)
    out.append({**p, "aliases": aliases.get(p["qid"], [])[:40], "pageviews_12mo": views})
    if (i + 1) % 100 == 0:
        json.dump(out, open(OUT, "w"), ensure_ascii=False)
        print(f"  {i+1}/{len(ranked)}", flush=True)
    time.sleep(0.12)

json.dump(out, open(OUT, "w"), ensure_ascii=False)
got = sum(1 for r in out if r.get("pageviews_12mo"))
print(f"wrote {len(out)} rows, {got} with pageviews", flush=True)
