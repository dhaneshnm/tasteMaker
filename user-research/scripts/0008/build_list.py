#!/usr/bin/env python3
"""Merge pageviews + venues + pool coverage into the adjudicated theme list (0008).

Adjudication is the 0007 §3.2 analog: the Wikidata class queries return real
themes mixed with things no painting reader can browse by (rapping as an art
movement, vaporwave as an art genre, shellac as a painting material). Every
KEEP/REJECT in the top of each axis is hand-decided here with its reason
recorded; below the adjudicated head, items are marked unadjudicated tail.

Output: user-research/data/0008-recognizable-themes.json
"""
import json

pv = json.load(open("user-research/data/0008-pageviews.json"))["themes"]
cov = json.load(open("user-research/data/0008-pool-coverage.json"))
ceiling = json.load(open("user-research/data/0008-movement-ceiling.json"))

# ---- adjudication verdicts (hand-decided, reason recorded) -----------------
# REJECT: not a theme a reader browses paintings by. KEEP-FLAG: kept, with a
# named caveat (umbrella term, study term, cross-listed).
VERDICTS = {
    "movement": {
        "Renaissance": ("keep", "era+movement; pageviews include non-painting interest — flagged umbrella"),
        "Romanticism": ("keep", "umbrella (lit+music+art) — flagged; painting sense is core"),
        "Art Deco": ("keep-flag", "design/architecture-heavy; few easel paintings"),
        "Bauhaus": ("reject", "school; design/architecture lookup, not a painting browse term"),
        "Art Nouveau": ("keep-flag", "poster/design-heavy; some painting (Klimt-adjacent)"),
        "Dada": ("keep", "visual-art movement"),
        "Impressionism": ("keep", "the canonical painting-browse movement"),
        "surrealism": ("keep", "painting-core movement"),
        "Baroque": ("keep", "painting-core era/movement"),
        "bohemianism": ("reject", "lifestyle, not an art style"),
        "avant-garde": ("reject", "meta-category, not browsable"),
        "kitsch": ("reject", "aesthetic judgment, not a browse category"),
        "Postmodernism": ("reject", "philosophy umbrella; not a painting browse term"),
        "Rococo": ("keep", "painting-core movement (force-added: class query missed it)"),
        "satire": ("reject", "literary genre in this usage"),
        "Orientalism": ("keep-flag", "painting genre-movement; term also names the critique"),
        "rapping": ("reject", "music"),
        "ukiyo-e": ("keep", "cross-listed with genre axis; Japanese tradition"),
        "modernism": ("keep-flag", "umbrella; 'modernist painting' is a real browse intent"),
        "cubism": ("keep", "painting-core"),
        "Pre-Raphaelite Brotherhood": ("keep", "painting-core"),
        "Harlem Renaissance": ("keep-flag", "cultural movement; painting side is real (walled 20th c.)"),
        "Futurism": ("keep", "painting-core"),
        "magic realism": ("keep-flag", "lit-dominant; painting sense exists"),
        "Britpop": ("reject", "music"),
        "Gothic art": ("keep", "painting+architecture era"),
        "Expressionism": ("keep", "painting-core"),
        "abstract art": ("keep", "style umbrella readers browse by"),
        "Classicism": ("keep-flag", "umbrella"),
        "Symbolism": ("keep", "painting-core"),
        "pop art": ("keep", "painting-core (walled 20th c.)"),
        "Neoclassicism": ("keep", "painting-core"),
        "realism": ("keep", "painting-core style"),
        "Post-impressionism": ("keep", "painting-core"),
        "Minimalism": ("keep-flag", "umbrella"),
        "Mannerism": ("keep", "painting-core"),
        "Fauvism": ("keep", "painting-core"),
        "Der Blaue Reiter": ("keep", "painting-core (force-added)"),
        "Naïve art": ("keep", "painting-core (force-added)"),
        "Folk art": ("keep-flag", "broad craft umbrella (force-added)"),
        "Abstract expressionism": ("keep", "painting-core (walled 20th c.)"),
        "epic poem": ("reject", "literature"),
        "humour": ("reject", "not an art movement"),
        "Academic art": ("keep", "painting-core"),
    },
    "genre": {
        "Impressionism": ("reject", "movement — counted on the movement axis"),
        "erotica": ("reject", "media umbrella; 'erotic art' carries the visual sense"),
        "satire": ("reject", "literary"),
        "ukiyo-e": ("keep", "tradition-genre; real browse term"),
        "vaporwave": ("reject", "music/net aesthetic"),
        "Allegory": ("keep", "painting genre (force-added)"),
        "visual arts": ("reject", "umbrella"),
        "solarpunk": ("reject", "net aesthetic"),
        "apotheosis": ("reject", "concept, not a browse genre"),
        "erotic art": ("keep-flag", "real genre; pool cannot serve it"),
        "graffiti": ("reject", "not paintings in this product's sense"),
        "shunga": ("keep-flag", "real genre; pool cannot serve it"),
        "ASCII art": ("reject", "not paintings"),
        "pastiche": ("reject", "meta-term"),
        "Trompe-l'œil": ("keep", "painting genre (force-added)"),
        "retrofuturism": ("reject", "net aesthetic"),
        "nude": ("keep", "painting genre; pool value exists"),
        "calligraphy": ("keep-flag", "adjacent art; pool holds calligraphic works in Asian holdings"),
        "outsider art": ("keep-flag", "real category; pool coverage unknown"),
        "Illuminated manuscript": ("keep", "format-genre; pool's Indic manuscript works are close kin (force-added)"),
        "fiction": ("reject", "literature"),
        "art of sculpture": ("reject", "different medium entirely"),
        "abstract art": ("keep", "cross-listed with movement axis"),
        "slice of life": ("reject", "media term; painting sense is 'genre painting'"),
        "azulejo": ("reject", "tiles"),
        "Icon": ("keep", "religious panel genre; pageviews include software-icon noise — flagged"),
        "still life": ("keep", "painting-core genre"),
        "vanitas": ("keep", "painting-core sub-genre"),
        "Madhubani art": ("keep-flag", "high demand; POOL HAS NONE (Kalighat ≠ Madhubani) (force-added)"),
        "Mughal painting": ("keep", "pool strength, 102 works (force-added)"),
        "self-portrait": ("keep", "painting genre"),
        "portrait": ("keep", "painting-core genre"),
        "Chinese painting": ("keep", "tradition; pool strength (force-added)"),
        "Landscape painting": ("keep", "painting-core genre (force-added)"),
        "Persian miniature": ("keep", "tradition; pool holds ~19 Persian/Islamic (force-added)"),
        "Thangka": ("keep", "tradition; ~24 Tibetan/Nepalese works (force-added)"),
        "Portrait painting": ("keep", "painting-core genre (force-added)"),
        "History painting": ("keep", "painting-core genre (force-added)"),
        "Buddhist art": ("keep", "subject-tradition; pool strength (force-added)"),
        "Panel painting": ("keep-flag", "format term (force-added)"),
        "Kalighat painting": ("keep", "pool strength, 44 works (force-added)"),
        "Japanese painting": ("keep", "tradition; pool strength 276 works (force-added)"),
        "Genre painting": ("keep", "painting-core genre (force-added)"),
        "Pahari painting": ("keep", "pool strength, 84 works (force-added)"),
        "Shan shui": ("keep", "Chinese landscape tradition (force-added)"),
        "religious art": ("keep", "painting-core genre; pool value exists"),
        "marine art": ("keep", "painting genre; pool value exists"),
        "Rajput painting": ("keep", "pool strength, 102 works (force-added)"),
        "Kangra painting": ("keep", "Pahari school (force-added)"),
        "Veduta": ("keep-flag", "cityscape kin"),
        "military art": ("keep-flag", "battle painting kin (force-added)"),
        "Bird-and-flower painting": ("keep", "East Asian genre; pool kin works exist (force-added)"),
        "Hindu art": ("keep", "subject-tradition (force-added)"),
        "Figure painting": ("keep", "painting genre (force-added)"),
        "cityscape": ("keep", "painting genre; pool value exists"),
    },
    "medium": {
        "chiaroscuro": ("keep-flag", "study/technique term, not a browse medium"),
        "shellac": ("reject", "materials-trade lookup"),
        "fresco painting": ("keep", "viewer-meaningful medium; pool has ~2"),
        "gouache paint": ("keep", "medium; pool has 8"),
        "pointillism": ("keep-flag", "technique bordering movement (Neo-impressionism)"),
        "oil painting": ("keep", "the canonical medium; pool 922"),
        "Mural": ("keep-flag", "format; pool ~0 (force-added)"),
        "acrylic paint": ("keep", "medium; pool has 1 — modern medium, CC0 wall"),
        "watercolor": ("keep", "medium; pool 56"),
        "en plein air": ("keep-flag", "practice term"),
        "Gold leaf": ("keep", "material; pool 484 gold-bearing works (force-added)"),
        "tenebrism": ("keep-flag", "study term"),
        "cephalopod ink": ("reject", "biology lookup"),
        "ink wash painting": ("keep", "viewer-meaningful; pool 761 ink works"),
        "dragon's blood": ("reject", "materials-trade"),
        "monochrome": ("keep-flag", "broad"),
        "grisaille": ("keep-flag", "study term"),
        "Pastel": ("keep", "medium; pool 0 (force-added)"),
        "gesso": ("reject", "materials-trade"),
        "sfumato": ("keep-flag", "study term"),
        "encaustic painting": ("keep-flag", "medium; pool 0"),
        "impasto": ("keep-flag", "study term"),
        "silverpoint": ("reject", "drawing tool"),
        "Byōbu": ("keep", "format; pool 83 folding screens (force-added)"),
        "Hanging scroll": ("keep", "format; pool 193 (force-added)"),
        "Handscroll": ("keep", "format; pool 19 (force-added)"),
        "Silk painting": ("keep", "support; pool 180 on silk (force-added)"),
        "tempera painting": ("keep", "medium; pool 457 tempera works"),
        "wash technique": ("reject", "technique jargon"),
        "action painting": ("keep-flag", "movement-technique (walled 20th c.)"),
    },
}

# ---- pool coverage mapping per kept theme ---------------------------------
g = cov["genre"]["shipped"]
probe = {k: v["probe_hits_on_genre_nil"] for k, v in cov["genre"]["keyword_probe_headroom"].items()}
t = cov["tradition"]
m = cov["medium"]
mv = ceiling["movement_work_counts_in_sample"]

POOL_MAP = {
    # label -> (works_now_reachable, route)
    "Impressionism": (mv.get("Impressionism", 0), "artist P135 (top-80-artist sample)"),
    "Post-impressionism": (mv.get("Post-impressionism", 0), "artist P135 (sample)"),
    "Romanticism": (mv.get("Romanticism", 0), "artist P135 (sample)"),
    "Baroque": (mv.get("Baroque", 0), "artist P135 (sample)"),
    "Rococo": (mv.get("Rococo", 0), "artist P135 (sample)"),
    "Neoclassicism": (mv.get("Neoclassicism", 0), "artist P135 (sample)"),
    "Expressionism": (mv.get("Expressionism", 0), "artist P135 (sample)"),
    "Symbolism": (mv.get("Symbolism", 0), "artist P135 (sample)"),
    "realism": (mv.get("realism", 0) + mv.get("French Realism", 0), "artist P135 (sample)"),
    "Renaissance": (242, "period facet proxy: 15th+16th century works"),
    "ukiyo-e": (t["Ukiyo-e (Edo)"], "culture strings (Edo period)"),
    "portrait": (g.get("Portrait", 0), "shipped genre"),
    "Portrait painting": (g.get("Portrait", 0), "shipped genre; +163 title-probe"),
    "Landscape painting": (g.get("Landscape", 0), "shipped genre; +210 title-probe"),
    "still life": (g.get("Still Life", 0), "shipped genre; +27 title-probe"),
    "religious art": (g.get("Religious Art", 0), "shipped genre; +302 title-probe"),
    "Icon": (g.get("Religious Art", 0), "kin of Religious Art value"),
    "nude": (g.get("Nude", 0), "shipped genre; +11 title-probe"),
    "marine art": (g.get("Marine Art", 0), "shipped genre; +12 title-probe"),
    "cityscape": (g.get("Cityscape", 0), "shipped genre; +1 title-probe"),
    "Mughal painting": (t["Mughal painting"], "culture strings"),
    "Rajput painting": (t["Rajput painting"], "culture strings"),
    "Pahari painting": (t["Pahari painting"], "culture strings"),
    "Kangra painting": (t["Pahari painting"], "culture strings (Pahari umbrella)"),
    "Kalighat painting": (t["Kalighat painting"], "culture strings"),
    "Madhubani art": (0, "POOL HAS NONE"),
    "Chinese painting": (t["Chinese painting"], "culture strings"),
    "Japanese painting": (t["Japanese painting"], "culture strings"),
    "Persian miniature": (t["Persian/Islamic"], "culture strings"),
    "Thangka": (t["Tibetan/Nepalese"], "culture strings"),
    "Buddhist art": (None, "subset of +302 religious title-probe; not separately measured"),
    "Hindu art": (None, "subset of +302 religious title-probe; not separately measured"),
    "Illuminated manuscript": (t["Jain manuscript"], "culture strings (Jain/Gujarat) — kin, not equal"),
    "oil painting": (m["paint_type"]["oil"], "medium strings"),
    "watercolor": (m["paint_type"]["watercolor"], "medium strings"),
    "tempera painting": (m["paint_type"]["tempera"], "medium strings"),
    "ink wash painting": (m["paint_type"]["ink"], "medium strings"),
    "gouache paint": (m["paint_type"]["gouache"], "medium strings"),
    "acrylic paint": (m["paint_type"]["acrylic"], "medium strings"),
    "Pastel": (m["paint_type"]["pastel"], "medium strings"),
    "fresco painting": (m["paint_type"]["fresco"], "medium strings"),
    "Gold leaf": (m["paint_type"]["gold"], "medium strings"),
    "Silk painting": (m["support"]["silk"], "medium strings (support)"),
    "Hanging scroll": (m["format"]["hanging scroll"], "medium strings (format)"),
    "Handscroll": (m["format"]["handscroll"], "medium strings (format)"),
    "Byōbu": (m["format"]["folding screen"], "medium strings (format)"),
}

out = {"generated_on": "2026-08-20", "axes": {}}
for axis, rows in pv.items():
    ranked = []
    verdicts = VERDICTS[axis]
    for r in rows:
        label = r["label"]
        verdict, reason = verdicts.get(label, (None, None))
        rec = {
            "label": label, "qid": r["qid"],
            "pageviews_12mo": r["pageviews_12mo"],
            "force_added": r["force_added"],
            "verdict": verdict or "unadjudicated-tail",
            "verdict_reason": reason,
        }
        if label in POOL_MAP:
            works, route = POOL_MAP[label]
            rec["pool_works"] = works
            rec["pool_route"] = route
        ranked.append(rec)
    kept = [r for r in ranked if r["verdict"].startswith("keep")]
    out["axes"][axis] = {
        "measured": len(ranked),
        "kept": len(kept),
        "rejected": sum(1 for r in ranked if r["verdict"] == "reject"),
        "unadjudicated_tail": sum(1 for r in ranked if r["verdict"] == "unadjudicated-tail"),
        "themes": ranked,
    }

with open("user-research/data/0008-recognizable-themes.json", "w") as f:
    json.dump(out, f, indent=1)

for axis, a in out["axes"].items():
    print(f"== {axis}: {a['kept']} kept / {a['rejected']} rejected / {a['unadjudicated_tail']} tail ==")
    shown = 0
    for r in a["themes"]:
        if not r["verdict"].startswith("keep"):
            continue
        shown += 1
        if shown > 20:
            break
        pw = r.get("pool_works")
        pool = f"pool={pw if pw is not None else '?'}" if "pool_works" in r else "pool=unmapped"
        flag = " [FLAG]" if r["verdict"] == "keep-flag" else ""
        print(f"  {r['pageviews_12mo']:>9,} {r['label'][:34]:34s} {pool:12s}{flag}")
