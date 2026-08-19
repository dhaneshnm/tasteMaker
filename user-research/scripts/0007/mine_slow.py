#!/usr/bin/env python3
import json, os, sys, time, urllib.parse, urllib.request
S = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(S, "corpus.jsonl")
UA = {"User-Agent": "Tondo/1.0 (daily-art app research; dhanesh.n.m19@gmail.com)"}
SUBS = ["Art", "painting", "ArtHistory", "museum"]
QUERIES = ["favorite artist", "favourite artist", "favorite painter", "favorite painting",
           "underrated artist", "best painter", "artist you love"]
DEADLINE = time.time() + float(sys.argv[1] if len(sys.argv) > 1 else 2400)
GAP = 6.0
seen = set()
if os.path.exists(OUT):
    for l in open(OUT):
        try: seen.add(json.loads(l)["id"])
        except Exception: pass
def get(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
            return json.load(r)
    except Exception as e:
        return {"_err": str(e)}
f = open(OUT, "a")
n = 0
for sub in SUBS:
    for q in QUERIES:
        for ep, kind in (("comment", "comment"), ("submission", "submission")):
            before = ""
            for page in range(8):
                if time.time() > DEADLINE: break
                d = get(f"https://api.pullpush.io/reddit/search/{ep}/?q={urllib.parse.quote(q)}"
                        f"&subreddit={sub}&size=100{before}")
                time.sleep(GAP)
                items = (d or {}).get("data") or []
                if not items: break
                for x in items:
                    i = x.get("id")
                    if not i or i in seen: continue
                    text = x.get("body") or " ".join(filter(None, [x.get("title"), x.get("selftext")]))
                    if not text or len(text) < 15: continue
                    seen.add(i); n += 1
                    f.write(json.dumps({"id": i, "kind": kind, "subreddit": x.get("subreddit") or sub,
                        "created_utc": x.get("created_utc"), "text": text[:4000],
                        "score": x.get("score"), "api": "pullpush", "query": q}, ensure_ascii=False) + "\n")
                f.flush()
                oldest = min((x.get("created_utc") or 0) for x in items)
                if not oldest: break
                before = f"&before={int(oldest)}"
            print(f"{sub}/{q}/{ep}: total {n}", flush=True)
        if time.time() > DEADLINE: break
    if time.time() > DEADLINE: break
print(f"done, {n} documents", flush=True)
