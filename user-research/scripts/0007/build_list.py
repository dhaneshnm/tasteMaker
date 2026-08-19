#!/usr/bin/env python3
"""Build the ranked recognizable-artist list from two independent instruments."""
import json, os, re
S = os.path.dirname(os.path.abspath(__file__))

# Occupations that mean "famous for something other than making pictures".
# Present in ANY of them disqualifies, because pageview rank is then measuring
# the other career: Jim Carrey, Dennis Hopper and Viggo Mortensen all list
# painter, and all three outrank Vermeer on pageviews.
BLOCK = {
    "Q82955": "politician", "Q33999": "actor", "Q177220": "singer", "Q639669": "musician",
    "Q2526255": "film director", "Q3282637": "film producer", "Q245068": "comedian",
    "Q484876": "chief executive", "Q43845": "businessperson", "Q937857": "footballer",
    "Q10800557": "film actor", "Q10798782": "television actor", "Q2405480": "voice actor",
    "Q753110": "songwriter", "Q488205": "singer-songwriter", "Q855091": "guitarist",
    "Q36180": "writer-only guard (kept unless paired)", "Q116": "monarch",
    "Q484188": "serial killer", "Q1930187": "journalist", "Q212238": "civil servant",
    "Q189290": "military officer", "Q1622272": "university teacher", "Q11631": "astronaut",
    "Q2259451": "stage actor", "Q4610556": "model", "Q13235160": "television presenter",
    "Q193391": "diplomat", "Q47064": "military personnel", "Q12299841": "cricketer",
    "Q3455803": "director", "Q578109": "occultist", "Q211346": "psychiatrist",
    "Q6625963": "novelist", "Q4964182": "philosopher", "Q1650915": "researcher",
    "Q11774202": "essayist", "Q170790": "mathematician", "Q1234713": "theologian",
    "Q131512": "farmer",
    # Royalty and gentry who painted as an accomplishment. Their pageviews
    # measure the throne, not the pictures: five consorts and princesses
    # outranked Vermeer before this was added.
    "Q2478141": "aristocrat", "Q5784340": "consort", "Q477406": "regent", "Q186360": "nurse",
    # NOT "art collector" (Q10732476) or "patron of the arts": blocking those
    # deleted Rembrandt and Vermeer, both of whom dealt and collected —
    # Rembrandt's collecting is what bankrupted him. Joséphine de Beauharnais,
    # the name that prompted the idea, is hand-rejected below instead.
    # Picture-makers, but not the kind a CC0 museum collection can hold. Keeping
    # them would inflate the `absent` bucket without informing anything.
    "Q191633": "mangaka", "Q715301": "comics artist", "Q11892507": "comics writer",
    "Q17098559": "penciller", "Q1153051": "inker", "Q266569": "animator",
    "Q1062952": "character designer", "Q5762300": "storyboard artist", "Q28389": "screenwriter",
    # Famous for a cause, not a canvas.
    "Q15253558": "activist", "Q19509201": "LGBTQ rights activist",
    "Q66288471": "trans activist", "Q96034777": "HIV/AIDS activist", "Q337084": "drag queen",
    # Photography and music are different rooms. Tondo ships paintings.
    "Q33231": "photographer", "Q36834": "composer", "Q486748": "pianist",
    "Q1028181": None,  # painter itself — never blocks
}
BLOCK.pop("Q1028181"); BLOCK.pop("Q36180")  # writer alone is not disqualifying (Blake, Tagore)

rows = {r["qid"]: r for r in json.load(open(os.path.join(S, "pageviews.json")))}
occ = json.load(open(os.path.join(S, "occupations.json")))
mentions = {a["qid"]: a for a in json.load(open(os.path.join(S, "mentions.json")))["artists"]}

# Adjudicated by hand, with the reason recorded. Structured occupation cannot
# reach these: Wikidata lists Joseph Merrick — the Elephant Man — with the single
# occupation "artist", for a cardboard church he built in hospital.
HAND_REJECT = {
    "Joseph Merrick": "Wikidata's only occupation is 'artist', for a cardboard model made in hospital; recognized as a medical case, not a picture-maker",
    "Bob Ross": "a genuine painter and genuinely recognizable, but a television teacher whose work no museum collects — he can never be filled or fairly reported as a gap",
    "Adolf Hitler": "recognized for genocide; the pageviews are not about the watercolours",
    "Winston Churchill": "recognized as a war leader who painted",
    "Prince Charles III": "recognized as a monarch who paints",
    "Victoria, Princess Royal": "a princess who painted; the pageviews are dynastic (no aristocrat tag on Wikidata to catch her structurally)",
    "Luke the Evangelist": "the patron saint of painters, not a painter — legendary attribution",
    "Lili Elbe": "recognized as a transgender pioneer through a memoir and a film, not through the paintings",
    "Édouard-Henri Avril": "pageviews driven by the erotic illustrations' circulation, not by gallery recognition",
    "Le Corbusier": "recognized as an architect who also painted; blocking 'architect' structurally would have deleted Michelangelo, Rembrandt and El Greco, so this one is by hand",
    "Ulrika Eleonora I of Sweden": "a queen who painted; dynastic pageviews",
    "Johann Wolfgang von Goethe": "recognized as a writer; the drawings are a footnote",
    "Dario Fo": "recognized as a playwright and Nobel laureate",
    "Joséphine de Beauharnais": "an empress who collected and patronised art; the Wikidata occupations are collector, patron and draftsperson, and blocking those structurally would delete Rembrandt and Vermeer",
    "Peter Handke": "recognized as a writer and Nobel laureate",
}

kept, rejected = [], []
for qid, r in rows.items():
    pv = r.get("pageviews_12mo")
    bad = [BLOCK[o] for o in occ.get(qid, []) if o in BLOCK]
    if r["name"] in HAND_REJECT:
        rejected.append({"name": r["name"], "pageviews_12mo": pv,
                         "reason": HAND_REJECT[r["name"]] + " [hand-adjudicated]"})
        continue
    if bad:
        rejected.append({"name": r["name"], "pageviews_12mo": pv,
                         "reason": f"Wikidata occupation {bad[0]} — recognizable, but not as a picture-maker"})
        continue
    if pv is None:
        rejected.append({"name": r["name"], "reason": "no Wikipedia pageview data"}); continue
    kept.append({**r, "mentions": mentions.get(qid, {}).get("mentions", 0),
                 "by_subreddit": mentions.get(qid, {}).get("by_subreddit", {})})

kept.sort(key=lambda r: -r["pageviews_12mo"])
# ranks for the divergence report
pv_rank = {r["qid"]: i + 1 for i, r in enumerate(kept)}
by_mentions = sorted([r for r in kept if r["mentions"] > 0], key=lambda r: -r["mentions"])
mn_rank = {r["qid"]: i + 1 for i, r in enumerate(by_mentions)}

TOP = 200
final = kept[:TOP]
# Mirror evidence beats the date rule. A name with works in the four CC0
# mirrors is demonstrably reachable, whatever a term calculation says — the
# first version labelled Kandinsky, Munch, Mondrian and Matisse "in copyright,
# unreachable at any effort" while their works sat in the mirrors (code review
# finding 3). Only when there is no evidence either way does the US term
# decide: 95 years from publication, so published before 1931 in 2026.
US_CUTOFF = 1931
IN_MIRRORS = set()
_mirror_file = os.path.join(S, "mirror-artist-slugs.json")
if os.path.exists(_mirror_file):
    IN_MIRRORS = set(json.load(open(_mirror_file)))

def slugish(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower().strip()).strip("-")
out = []
for i, r in enumerate(final):
    died = r.get("died")
    if slugish(r["name"]) in IN_MIRRORS:
        rights = "public_domain"            # evidence, not a term calculation
    elif died is not None and died < US_CUTOFF:
        rights = "public_domain"
    else:
        rights = "walled"
    d = None
    if r["qid"] in mn_rank:
        gap = mn_rank[r["qid"]] - pv_rank[r["qid"]]
        if gap <= -60: d = "reddit-inflated"
        elif gap >= 60: d = "pageview-inflated"
    elif pv_rank[r["qid"]] <= 60:
        d = "pageview-inflated"
    out.append({"rank": i + 1, "name": r["name"], "aliases": r.get("aliases", [])[:25],
                "qid": r["qid"], "wikipedia_title": r["title"], "sitelinks": r["sitelinks"],
                "born": r.get("born"), "died": died, "rights": rights,
                "pageviews_12mo": r["pageviews_12mo"], "mentions": r["mentions"],
                "by_subreddit": r["by_subreddit"], "divergence": d})

doc = {
  "generated_on": "2026-08-19",
  "method": ("Ranked by English-Wikipedia pageviews over 2025-08..2026-07 for painters drawn "
             "from a Wikidata dictionary, filtered by structured occupation to drop people "
             "recognizable for something other than making pictures. Reddit mention frequency "
             "across r/Art, r/painting, r/ArtHistory, r/museum and r/ArtPorn is reported as an "
             "independent second instrument and is never averaged into the ranking."),
  "corpus": {"documents": sum(1 for _ in open(os.path.join(S, "corpus.jsonl"))),
             "venues": ["r/Art", "r/painting", "r/ArtHistory", "r/museum", "r/ArtPorn"],
             "dictionary_size": len(rows), "measured_for_pageviews": len(rows)},
  "names": out,
  "rejected": sorted(rejected, key=lambda r: -(r.get("pageviews_12mo") or 0))[:80],
}
json.dump(doc, open(os.path.join(S, "recognizable-names.json"), "w"), ensure_ascii=False, indent=2)
print(f"kept {len(out)} names, rejected {len(rejected)}")
print(f"  public_domain {sum(1 for n in out if n['rights']=='public_domain')}, "
      f"walled {sum(1 for n in out if n['rights']=='walled')}")
print(f"  with a Reddit mention: {sum(1 for n in out if n['mentions'])}")
for n in out[:30]:
    print(f"  {n['rank']:>3} {n['pageviews_12mo']:>9,} m={n['mentions']:<2} {n['rights'][:6]:<6} {n['name']}")
