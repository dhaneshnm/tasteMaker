#!/usr/bin/env python3
"""Map the committed 2,000-work pool against the theme axes (0008 research).

Four local measurements, no network:
  1. genre     — shipped `genre` values (0022 R2 fill) + a title/description
                 keyword probe over the genre-nil works: how many MORE works a
                 title-keyword route could reach per genre. Raw counts — the
                 probe is a candidate-finder, not a classifier; hits need
                 adjudication before anything fills from them.
  2. medium    — the raw `medium` strings normalized to paint-type, support,
                 and East-Asian format (scroll/screen/album). The one axis the
                 pool already carries near-complete data for.
  3. tradition — named painting traditions recoverable from culture/country
                 strings (Mughal, Pahari, Kalighat, Edo...) — the pool's
                 actual strengths, invisible to every shipped facet.
  4. period    — the shipped century facet, read from the dev DB.

Input : db/seeds/paintings.json (the committed manifest), storage/development.sqlite3
Output: user-research/data/0008-pool-coverage.json
"""
import json, re, sqlite3, os
from collections import Counter

works = json.load(open("db/seeds/paintings.json"))

# ---- 1. genre: shipped + keyword-probe headroom ----------------------------
GENRE_KEYWORDS = {
    "Portrait": [r"\bportrait\b", r"\bself-portrait\b"],
    "Landscape": [r"\blandscape\b", r"\bmountain[s]?\b.*\briver\b", r"\bview of\b"],
    "Still Life": [r"\bstill life\b", r"\bvase of\b", r"\bbouquet\b", r"\bfruit\b.*\btable\b"],
    "Religious Art": [r"\bmadonna\b", r"\bvirgin\b", r"\bchrist\b", r"\bsaint\b", r"\bst\. ",
                       r"\bbuddha\b", r"\bbodhisattva\b", r"\bkrishna\b", r"\bshiva\b",
                       r"\bvishnu\b", r"\bdevi\b", r"\bcrucifixion\b", r"\bannunciation\b",
                       r"\badoration\b", r"\bholy family\b", r"\bmadonna and child\b",
                       r"\bguanyin\b", r"\barhat\b", r"\bdeit(y|ies)\b", r"\bgoddess\b"],
    "Marine Art": [r"\bseascape\b", r"\bharbor\b", r"\bharbour\b", r"\bships? at\b",
                    r"\bshipwreck\b", r"\bnaval\b"],
    "Cityscape": [r"\bcityscape\b", r"\bview of (the )?(city|town)\b", r"\bstreet scene\b",
                   r"\bcanal\b.*\bvenice\b", r"\bvenice\b.*\bcanal\b"],
    "Mythological Art": [r"\bvenus\b", r"\bapollo\b", r"\bdiana\b", r"\bcupid\b",
                          r"\bjupiter\b", r"\bbacchus\b", r"\bmytholog", r"\bnymph\b"],
    "Animal Painting": [r"\bhorses?\b", r"\btigers?\b", r"\blions?\b", r"\belephants?\b",
                         r"\bbirds?\b", r"\bdogs?\b", r"\bcats?\b", r"\bfalcons?\b"],
    "Genre Scene": [r"\binterior with\b", r"\bpeasants?\b", r"\bmarket\b", r"\btavern\b",
                     r"\bdomestic scene\b"],
    "Nude": [r"\bnude\b", r"\bbather[s]?\b"],
    "Flowers": [r"\bflowers?\b", r"\bblossoms?\b", r"\bpeon(y|ies)\b", r"\blotus\b",
                 r"\bchrysanthemum\b", r"\borchid\b", r"\bplum\b.*\bbranch\b"],
}

shipped = Counter(w.get("genre") for w in works if w.get("genre"))
probe = {}
for genre, patterns in GENRE_KEYWORDS.items():
    rx = re.compile("|".join(patterns), re.IGNORECASE)
    hits = [w for w in works if not w.get("genre")
            and rx.search((w.get("title") or "") + " " + (w.get("description") or "")[:400])]
    probe[genre] = {"probe_hits_on_genre_nil": len(hits),
                    "sample_titles": [h.get("title", "")[:90] for h in hits[:5]]}

# ---- 2. medium normalization ----------------------------------------------
PAINT_TYPES = {
    "oil": r"\boil\b", "tempera": r"\btempera\b", "ink": r"\bink\b",
    "watercolor": r"\bwater ?colou?r|\baquarelle\b", "gouache": r"\bgouache\b",
    "acrylic": r"\bacrylic\b", "pastel": r"\bpastel\b", "fresco": r"\bfresco\b",
    "lacquer": r"\blacquer\b", "gold": r"\bgold\b", "charcoal": r"\bcharcoal\b",
    "graphite": r"\bgraphite\b", "enamel": r"\benamel\b",
}
SUPPORTS = {
    "canvas": r"\bcanvas\b|\bfabric\b|\blinen\b", "paper": r"\bpaper\b",
    "silk": r"\bsilk\b", "panel/wood": r"\bpanel\b|\bwood\b|\boak\b|\bpoplar\b",
    "plaster": r"\bplaster\b", "cloth/cotton": r"\bcloth\b|\bcotton\b",
}
FORMATS = {
    "hanging scroll": r"\bhanging scroll\b", "handscroll": r"\bhandscroll\b",
    "folding screen": r"\bfolding screen\b|\bscreen\b.*\bpanel\b",
    "album leaf": r"\balbum leaf\b", "fan": r"\bfan\b", "thangka": r"\bthang-?ka\b",
}

def norm_counts(table):
    counts = {}
    for name, pat in table.items():
        rx = re.compile(pat, re.IGNORECASE)
        counts[name] = sum(1 for w in works if rx.search(w.get("medium") or ""))
    return counts

medium_missing = sum(1 for w in works if not (w.get("medium") or "").strip())

# ---- 3. traditions from culture/country/department -------------------------
TRADITIONS = {
    "Mughal painting": r"\bmughal\b",
    "Pahari painting": r"\bpahari\b|\bkangra\b|\bguler\b|\bbasohli\b",
    "Rajput painting": r"\brajput\b|\bmewar\b|\bmarwar\b|\bbundi\b|\bkota\b|\bbikaner\b|\bjaipur\b|\brajasthan\b",
    "Kalighat painting": r"\bkalighat\b",
    "Jain manuscript": r"\bjain\b|\bgujarat\b",
    "Japanese painting": r"\bjapan\b",
    "Ukiyo-e (Edo)": r"\bedo period\b|\bukiyo\b",
    "Chinese painting": r"\bchina\b|\bchinese\b",
    "Korean painting": r"\bkorea\b",
    "Persian/Islamic": r"\bpersia\b|\biran\b|\bislamic\b|\bsafavid\b|\bqajar\b|\bottoman\b",
    "Tibetan/Nepalese": r"\btibet\b|\bnepal\b|\bhimalaya\b",
}
trad_counts = {}
for name, pat in TRADITIONS.items():
    rx = re.compile(pat, re.IGNORECASE)
    n = sum(1 for w in works if rx.search(
        " ".join(str(w.get(k) or "") for k in ("culture", "country", "department"))))
    trad_counts[name] = n

# ---- 4. period facet from dev DB -------------------------------------------
period = {}
db = "storage/development.sqlite3"
if os.path.exists(db):
    cur = sqlite3.connect(db).execute(
        "SELECT COALESCE(NULLIF(period,''),'(none)'), COUNT(*) FROM paintings GROUP BY 1 ORDER BY 2 DESC")
    period = dict(cur.fetchall())

out = {
    "generated_on": "2026-08-20",
    "pool_size": len(works),
    "genre": {
        "shipped": dict(shipped.most_common()),
        "shipped_total": sum(shipped.values()),
        "keyword_probe_headroom": probe,
        "note": "probe hits are candidates needing adjudication, not fills",
    },
    "medium": {
        "paint_type": norm_counts(PAINT_TYPES),
        "support": norm_counts(SUPPORTS),
        "format": norm_counts(FORMATS),
        "empty_medium_field": medium_missing,
    },
    "tradition": trad_counts,
    "period_facet_shipped": period,
}
with open("user-research/data/0008-pool-coverage.json", "w") as f:
    json.dump(out, f, indent=1)
print(json.dumps(out, indent=1)[:2600])
