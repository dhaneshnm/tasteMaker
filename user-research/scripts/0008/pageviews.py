#!/usr/bin/env python3
"""12-month English-Wikipedia pageviews for theme candidates (0008 research).

Same instrument and window as 0007: monthly per-article user pageviews,
2025-08-01 -> 2026-08-01, summed. Sitelinks decided who is worth measuring
(top N per axis); FORCE_ADDS are hand-added names the Wikidata class queries
missed — mostly the pool's own strengths (Mughal/Pahari/Kalighat painting,
scrolls, screens) plus canonical painting genres modeled outside `art genre`
(Landscape painting, History painting). Each is flagged force_added so a
reader can separate instrument output from hand additions.

Input : user-research/data/0008-candidates.json
Output: user-research/data/0008-pageviews.json
"""
import json, sys, time, urllib.parse, urllib.request

UA = {"User-Agent": "TondoResearch/0.1 (dhanesh.n.m19@gmail.com)"}
TOP_N = {"movement": 100, "genre": 100, "medium": 60}

FORCE_ADDS = {
    "movement": ["Rococo", "Der Blaue Reiter", "Orientalism", "Naïve art", "Folk art"],
    "genre": [
        "Landscape painting", "Portrait painting", "History painting", "Genre painting",
        "Figure painting", "Animal painting", "Allegory", "Panel painting",
        "Buddhist art", "Hindu art", "Icon", "Illuminated manuscript",
        "Persian miniature", "Mughal painting", "Rajput painting", "Pahari painting",
        "Kalighat painting", "Kangra painting", "Madhubani art", "Chinese painting",
        "Shan shui", "Japanese painting", "Thangka", "Bird-and-flower painting",
        "Literati painting", "Vanitas", "Trompe-l'œil", "Military art",
    ],
    "medium": ["Pastel", "Silk painting", "Hanging scroll", "Handscroll", "Byōbu",
               "Mural", "Gold leaf"],
}


def get(url, timeout=30):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(2 * (attempt + 1))
        except Exception:
            time.sleep(2 * (attempt + 1))
    return None


def resolve_title(title):
    """Canonical title + QID via enwiki API (follows redirects)."""
    url = ("https://en.wikipedia.org/w/api.php?action=query&redirects=1&prop=pageprops"
           "&ppprop=wikibase_item&format=json&titles=" + urllib.parse.quote(title))
    d = get(url)
    if not d:
        return None, None
    pages = d.get("query", {}).get("pages", {})
    for pid, p in pages.items():
        if pid == "-1":
            return None, None
        return p.get("title"), p.get("pageprops", {}).get("wikibase_item")
    return None, None


def pageviews(title):
    t = urllib.parse.quote(title.replace(" ", "_"), safe="")
    url = (f"https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/"
           f"en.wikipedia/all-access/user/{t}/monthly/2025080100/2026080100")
    d = get(url)
    if d is None:
        return None
    return sum(i["views"] for i in d.get("items", []))


def main():
    cands = json.load(open("user-research/data/0008-candidates.json"))["candidates"]
    out = {}
    not_found = []
    for axis in ["movement", "genre", "medium"]:
        rows = []
        measured = cands[axis][: TOP_N[axis]]
        titles_seen = set()
        for r in measured:
            rec = dict(r)
            rec["force_added"] = False
            rows.append(rec)
            titles_seen.add(r["wikipedia_title"].replace("_", " ").lower())
        for name in FORCE_ADDS[axis]:
            canon, qid = resolve_title(name)
            if canon is None:
                not_found.append({"axis": axis, "title": name})
                print(f"  NOT FOUND on enwiki: {name}", file=sys.stderr)
                continue
            if canon.lower() in titles_seen:
                continue
            titles_seen.add(canon.lower())
            rows.append({"qid": qid, "label": canon, "description": "(force-added)",
                         "sitelinks": None, "wikipedia_title": canon.replace(" ", "_"),
                         "force_added": True})
        for rec in rows:
            pv = pageviews(rec["wikipedia_title"])
            rec["pageviews_12mo"] = pv
            if pv is None:
                not_found.append({"axis": axis, "title": rec["wikipedia_title"],
                                  "reason": "no pageview data"})
            time.sleep(0.15)
        rows.sort(key=lambda r: -(r["pageviews_12mo"] or 0))
        out[axis] = rows
        print(f"{axis}: measured {len(rows)} "
              f"(top {rows[0]['label']} = {rows[0]['pageviews_12mo']:,})")

    with open("user-research/data/0008-pageviews.json", "w") as f:
        json.dump({"generated_on": "2026-08-20",
                   "window": "2025-08-01..2026-08-01 monthly, en.wikipedia, agent=user",
                   "not_found": not_found, "themes": out}, f, indent=1)
    print("wrote user-research/data/0008-pageviews.json;",
          f"{len(not_found)} not-found entries recorded")


if __name__ == "__main__":
    main()
