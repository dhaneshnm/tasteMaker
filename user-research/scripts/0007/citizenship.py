#!/usr/bin/env python3
import json, os, time, urllib.request
from collections import Counter
S = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Tondo/1.0 (daily-art app research; dhanesh.n.m19@gmail.com)"}
doc = json.load(open(os.path.join(S, "recognizable-names.json")))
qids = [n["qid"] for n in doc["names"]]
cit = {}
for i in range(0, len(qids), 50):
    url = (f"https://www.wikidata.org/w/api.php?action=wbgetentities&ids={'|'.join(qids[i:i+50])}"
           f"&props=claims&format=json")
    ents = {}
    for a in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45) as r:
                ents = json.load(r)["entities"]; break
        except Exception: time.sleep(2*(a+1))
    for q, e in ents.items():
        ids = []
        for c in e.get("claims", {}).get("P27", []):
            try: ids.append(c["mainsnak"]["datavalue"]["value"]["id"])
            except Exception: pass
        cit[q] = ids
    time.sleep(0.3)
want = sorted({x for v in cit.values() for x in v})
labels = {}
for i in range(0, len(want), 50):
    url = (f"https://www.wikidata.org/w/api.php?action=wbgetentities&ids={'|'.join(want[i:i+50])}"
           f"&props=labels&languages=en&format=json")
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45) as r:
            for q, e in json.load(r)["entities"].items():
                labels[q] = e.get("labels", {}).get("en", {}).get("value", q)
    except Exception: pass
    time.sleep(0.3)

WESTERN = {"France","Italy","Kingdom of Italy","Netherlands","Dutch Republic","Spain","Germany",
 "Kingdom of Prussia","United Kingdom","Kingdom of Great Britain","England","Kingdom of England",
 "United States of America","Belgium","Austria","Austria-Hungary","Switzerland","Sweden","Norway",
 "Denmark","Russian Empire","Russia","Soviet Union","Poland","Ireland","Portugal","Greece","Canada",
 "Habsburg monarchy","Cisleithania","Papal States","Republic of Venice","Duchy of Milan","Kingdom of France",
 "Grand Duchy of Tuscany","Republic of Florence","Kingdom of the Netherlands","Czechoslovakia","Hungary",
 "Finland","Kingdom of Sardinia","Kingdom of Naples","Scotland","Wales","Australia","New Zealand",
 "Kingdom of Bavaria","German Empire","Weimar Republic","Nazi Germany","Kingdom of Sweden","Second Polish Republic",
 "Kingdom of Denmark","Serbia","Croatia","Romania","Ukraine","Lithuania","Latvia","Estonia","Slovenia","Bulgaria"}
per = {}
for n in doc["names"]:
    names_ = [labels.get(x, x) for x in cit.get(n["qid"], [])]
    n["citizenship"] = names_
    per[n["name"]] = "western" if (names_ and all(x in WESTERN for x in names_)) else ("unknown" if not names_ else "non_western")
json.dump(doc, open(os.path.join(S, "recognizable-names.json"), "w"), ensure_ascii=False, indent=2)
c = Counter(per.values())
print("citizenship split:", dict(c))
print("non-Western names:", [k for k, v in per.items() if v == "non_western"][:40])
print("unknown:", [k for k, v in per.items() if v == "unknown"][:12])
