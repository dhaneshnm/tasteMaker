#!/usr/bin/env python3
"""Count unprompted artist mentions in the Reddit corpus against the Wikidata dictionary.

Rules, stated because they ARE the instrument:
 1. Case-insensitive, whole-name, word-boundary match of the label and each alias.
 2. A bare surname counts only when exactly one dictionary painter has it and it is
    >= 5 characters. Ambiguous surnames are recorded separately, never assigned.
 3. One document contributes at most one mention per artist, so a single gushing
    comment cannot inflate a name.
 4. Names that are also ordinary English words are excluded outright.
"""
import json, os, re, sys
from collections import defaultdict, Counter

S = os.path.dirname(os.path.abspath(__file__))
MIN_SITELINKS = int(sys.argv[1] if len(sys.argv) > 1 else 8)

# A surname that is also an ordinary English word, a first name, or a place is
# not usable as a bare-surname match: the corpus is art talk, so "Story",
# "Matter", "Corner", "Paris" and "France" all fired on real painters whose
# surnames happen to be those words. Measured on the first run — the top seven
# mentions were all this failure.
STOP = set("""art artist artists painting paintings painter modern young grant white black brown green
rose stone wood park hill west east north south may june march order king queen power light dark
love life death time water river hand head still master school gallery museum print blue red gold
silver flower garden bridge church house field forest sea sky moon sun star cloud mountain
story matter corner haven pierce marks joseph france paris london berlin rome venice florence
prince princess saint point valentine russell howard philip martin lewis morris james john james
close hunter fisher walker turner baker parker cooper carter foster porter potter miller taylor
brooks rivers woods banks stone field green king bishop knight ward page hall wells reed
cotton cross bell scott young allen morgan murphy kelly ross reid gray hayes""".split())

painters = {}
for line in open(os.path.join(S, "raw_core.jsonl")):
    try: r = json.loads(line)
    except Exception: continue
    qid = r["item"].rsplit("/", 1)[-1]
    sl = int(r.get("sitelinks") or 0)
    if sl < MIN_SITELINKS: continue
    def year(v):
        v = (v or "").lstrip("+")
        return int(v[:4]) if v[:4].isdigit() else None
    art = r.get("article") or ""
    title = art.rsplit("/", 1)[-1] if art else ""
    prev = painters.get(qid)
    if prev is None or sl > prev["sitelinks"]:
        painters[qid] = {"qid": qid, "name": r.get("label") or title.replace("_", " "),
                         "title": title, "sitelinks": sl,
                         "born": year(r.get("birth")), "died": year(r.get("death"))}

aliases = defaultdict(set)
for line in open(os.path.join(S, "raw_alias.jsonl")):
    try: r = json.loads(line)
    except Exception: continue
    q = r["item"].rsplit("/", 1)[-1]
    if q in painters: aliases[q].add(r["alias"])

def norm(s): return re.sub(r"[^a-z0-9 ]", " ", s.lower()).split()

# full-name index
by_phrase = defaultdict(set)
for q, p in painters.items():
    for spelling in {p["name"], *aliases[q]}:
        toks = norm(spelling)
        if len(toks) < 2 or len(" ".join(toks)) < 6: continue
        by_phrase[" ".join(toks)].add(q)

# Unambiguous surname index. Restricted to painters notable enough that a bare
# surname is plausibly what a person typed — below this the surname match is
# almost always a collision with an ordinary word or a more famous non-painter.
SURNAME_MIN_SITELINKS = 25
surname = defaultdict(set)
for q, p in painters.items():
    toks = norm(p["name"])
    if len(toks) >= 2 and len(toks[-1]) >= 5 and toks[-1] not in STOP and p["sitelinks"] >= SURNAME_MIN_SITELINKS:
        surname[toks[-1]].add(q)
ambiguous = {s for s, qs in surname.items() if len(qs) > 1}
solo = {s: next(iter(qs)) for s, qs in surname.items() if len(qs) == 1}

docs = [json.loads(l) for l in open(os.path.join(S, "corpus.jsonl"))]
mentions = defaultdict(lambda: {"docs": set(), "subs": Counter(), "examples": []})
amb_hits = Counter()

for d in docs:
    toks = norm(d["text"])
    hit = set()
    for n in (4, 3, 2):
        for i in range(len(toks) - n + 1):
            phrase = " ".join(toks[i:i + n])
            for q in by_phrase.get(phrase, ()):
                hit.add(q)
    for t in toks:
        if t in ambiguous: amb_hits[t] += 1
        elif t in solo: hit.add(solo[t])
    for q in hit:
        m = mentions[q]
        m["docs"].add(d["id"]); m["subs"][d["subreddit"]] += 1
        if len(m["examples"]) < 5:
            idx = d["text"].lower().find(norm(painters[q]["name"])[-1])
            m["examples"].append({"doc_id": d["id"],
                                  "snippet": d["text"][max(0, idx - 60):idx + 140].replace("\n", " ")})

out = []
for q, m in mentions.items():
    p = painters[q]
    out.append({**p, "aliases": sorted(aliases[q])[:30], "mentions": len(m["docs"]),
                "by_subreddit": dict(m["subs"]), "examples": m["examples"]})
out.sort(key=lambda r: (-r["mentions"], -r["sitelinks"]))

json.dump({"documents_scanned": len(docs), "dictionary_size": len(painters),
           "min_sitelinks": MIN_SITELINKS,
           "ambiguous_surnames": [a for a, _ in amb_hits.most_common(40)],
           "rules": __doc__.strip(), "artists": out},
          open(os.path.join(S, "mentions.json"), "w"), ensure_ascii=False)
print(f"{len(docs)} docs, dictionary {len(painters)} painters, {len(out)} artists mentioned")
for r in out[:25]:
    print(f"  {r['mentions']:>3}  {r['name']}  (sitelinks {r['sitelinks']})")
