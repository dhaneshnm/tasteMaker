#!/usr/bin/env python3
"""Salvage every Reddit document any collector wrote into one deduped corpus."""
import json, os, glob, sys
S = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(S, "corpus.jsonl")

def docs(obj):
    if isinstance(obj, dict):
        for k in ("data", "items", "results"):
            if isinstance(obj.get(k), list):
                yield from obj[k]; return
        if obj.get("id") and (obj.get("body") or obj.get("title")): yield obj
    elif isinstance(obj, list):
        for x in obj:
            if isinstance(x, dict): yield from docs(x)

seen, rows = set(), []
if os.path.exists(OUT):
    for l in open(OUT):
        try: seen.add(json.loads(l)["id"])
        except Exception: pass

files = sorted(set(glob.glob(os.path.join(S, "*.json")) + glob.glob(os.path.join(S, "*.jsonl"))))
skip = {"raw_core.jsonl", "raw_alias.jsonl", "corpus.jsonl", "pageviews.json",
        "painters.json", "recognizable-names.json", "mentions.json", "control.json"}
per_file = {}
for f in files:
    base = os.path.basename(f)
    if base in skip: continue
    try:
        if f.endswith(".jsonl"):
            objs = [json.loads(l) for l in open(f) if l.strip()]
        else:
            objs = [json.load(open(f))]
    except Exception:
        continue
    n = 0
    for o in objs:
        for d in docs(o):
            if not isinstance(d, dict): continue
            i = d.get("id")
            text = d.get("body") or " ".join(filter(None, [d.get("title"), d.get("selftext")]))
            sub = d.get("subreddit")
            if not i or i in seen or not text or len(text) < 15 or not sub: continue
            seen.add(i); n += 1
            rows.append({"id": i, "kind": "comment" if d.get("body") else "submission",
                         "subreddit": sub, "created_utc": d.get("created_utc"),
                         "text": text[:4000], "score": d.get("score"),
                         "api": "salvaged", "query": base})
    if n: per_file[base] = n

with open(OUT, "a") as fh:
    for r in rows: fh.write(json.dumps(r, ensure_ascii=False) + "\n")
print(f"salvaged {len(rows)} documents from {len(per_file)} files")
for k, v in sorted(per_file.items(), key=lambda x: -x[1]): print(f"  {v:>5}  {k}")
