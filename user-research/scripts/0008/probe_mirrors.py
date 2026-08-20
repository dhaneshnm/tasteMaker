#!/usr/bin/env python3
"""Expansion probe: per-theme stock in the four mirrors, outside the pool (0008 addendum).

For each under-supplied high-demand theme from 0008, count qualifying mirror works
NOT already in the committed pool. Qualifying = has a displayable image URL.
Description presence is counted separately (the text>=70% bar is pool-wide, so a
blurbless candidate is usable but budgeted).

Theme matching is regex over title+description+culture+medium+department — a
candidate-finder like the genre probe, NOT a curation: every count is a ceiling
that needs the same human adjudication `pool:curate` already applies.

Output: user-research/data/0008-mirror-expansion.json
"""
import json, re
from collections import Counter

pool = json.load(open("db/seeds/paintings.json"))
in_pool = {(w["source"], w["source_id"]) for w in pool}

mirror = []
for src in ["aic", "cma", "met", "mia"]:
    mirror.extend(json.load(open(f"tmp/pool/{src}.json")))
outside = [w for w in mirror if (w["source"], w["source_id"]) not in in_pool]

THEMES = {
    # theme -> (regex, fields)  fields: t=title, d=description, c=culture/country/dept, m=medium
    "ukiyo-e / Edo painting": (r"\bukiyo|\bedo period\b|floating world", "tdc"),
    "Madhubani": (r"\bmadhubani\b|\bmithila\b", "tdc"),
    "Still life / flowers": (r"\bstill life\b|\bflowers?\b|\bbouquet\b|\bvase of\b|\bblossom|\bpeon(y|ies)\b|\blotus\b|\bchrysanthemum", "td"),
    "Marine / seascape": (r"\bseascape\b|\bharbor\b|\bharbour\b|\bships? \b|\bshipwreck\b|\bcoast\b|\bmarine\b", "td"),
    "Cityscape / veduta": (r"\bcityscape\b|\bveduta\b|\bview of (the )?(city|town)\b|\bstreet scene\b|\bcanal\b|\bpiazza\b|\bplaza\b", "td"),
    "Mythological": (r"\bvenus\b|\bapollo\b|\bdiana\b|\bcupid\b|\bjupiter\b|\bbacchus\b|\bmytholog|\bnymph\b|\bmuse[s]?\b|\bhercules\b", "td"),
    "Vanitas / trompe-l'oeil": (r"\bvanitas\b|\btrompe\b|\bmemento mori\b", "td"),
    "Persian / Islamic miniature": (r"\bpersia|\biran\b|\bsafavid\b|\bqajar\b|\bislamic\b|\bshahnama|\bmughal\b", "tdc"),
    "Thangka / Tibetan-Nepalese": (r"\bthang-?ka\b|\btibet|\bnepal|\bmandala\b", "tdc"),
    "Icon (religious panel)": (r"\bicon\b|\bicons\b", "tdc"),
    "Portrait": (r"\bportrait\b", "td"),
    "Landscape": (r"\blandscape\b|\bview of\b", "td"),
    # movement proxies — era+region, loose by construction, flagged in report
    "Baroque-era European (1600-1750)": (None, "era:1600-1750"),
    "Romantic-era European (1780-1850)": (None, "era:1780-1850"),
}


def text_for(w, fields):
    parts = []
    if "t" in fields:
        parts.append(w.get("title") or "")
    if "d" in fields:
        parts.append((w.get("description") or "")[:400])
    if "c" in fields:
        parts += [str(w.get(k) or "") for k in ("culture", "country", "department")]
    if "m" in fields:
        parts.append(w.get("medium") or "")
    return " ".join(parts)


EURO = re.compile(r"europe|france|french|italy|italian|nether|dutch|flemish|german|spain|spanish|britain|british|english|austria", re.I)

out = {}
for theme, (pat, fields) in THEMES.items():
    if pat is None:
        lo, hi = map(int, fields.split(":")[1].split("-"))
        hits = [w for w in outside
                if w.get("year") and lo <= w["year"] <= hi
                and EURO.search(" ".join(str(w.get(k) or "") for k in ("culture", "country", "region", "artist")))]
    else:
        rx = re.compile(pat, re.I)
        hits = [w for w in outside if rx.search(text_for(w, fields))]
    with_img = [w for w in hits if w.get("image_url_800") or w.get("image_url_full")]
    with_desc = [w for w in with_img if (w.get("description") or "").strip()]
    out[theme] = {
        "outside_pool_hits": len(hits),
        "with_image": len(with_img),
        "with_image_and_description": len(with_desc),
        "by_source": dict(Counter(w["source"] for w in with_img)),
        "sample_titles": [f"{w.get('title','')[:70]} — {w.get('artist','?')[:30]} ({w['source']})"
                          for w in with_img[:5]],
    }

result = {"generated_on": "2026-08-20",
          "mirror_total": len(mirror), "outside_pool": len(outside), "themes": out}
with open("user-research/data/0008-mirror-expansion.json", "w") as f:
    json.dump(result, f, indent=1)
for k, v in out.items():
    print(f"{k:38s} img:{v['with_image']:5d}  +desc:{v['with_image_and_description']:5d}  {v['by_source']}")
