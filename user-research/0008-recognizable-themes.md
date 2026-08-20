# Recognizable Themes: what kind of painting a visitor actually goes looking for

**Project:** Tondo (Month 1, 12-month experiment, Fork B)
**Date:** 2026-08-20
**Purpose:** The 0007 method pointed at themes instead of artists — rank the genres,
movements/eras, and mediums a lay visitor actually looks up, then measure what the
committed 2,000-work pool can supply on each axis. Commissioned as the demand-side
companion to `specs/0022-what-kind-and-when` (which measured supply routes only) and
feeds whatever story next touches the `/feed` facets.
**Status:** Research document. No go/no-go authority — kill review stays 2026-08-31
against `BET.md`. Any direction change this triggers belongs in `decisions/`.

---

## 0. One planned instrument arrived dead

The plan reused 0007's two-instrument shape: Wikipedia pageviews as primary ranking,
Reddit archive mentions as the independent check. The Reddit half is gone entirely this
time — not thin, gone. pullpush.io now answers every request with an explicit refusal
("This website does not provide free scraping resources for agents… paid scraping
service"), and arctic-shift throttles to uselessness. 0007's 871-document corpus was
collected just before this wall went up; it cannot be re-collected or extended today.

Google autocomplete carried the corroboration role instead (26/26 prefixes returned).
Autocomplete proves a query exists and shows its phrasing; it does not measure volume.
The ranking below therefore has **one** quantitative instrument, not two — stated here
rather than discovered in the limitations.

---

## 1. Executive verdicts

| # | Claim | Verdict | Decisive evidence |
|---|---|---|---|
| C1 | A stable theme ranking can be built per axis | **YES** | 296 themes measured (104 movement, 125 genre, 67 medium), zero pageview retrieval failures. Distribution steep and sensible: Renaissance 1.10M → rank-20 movements still >200K |
| C2 | Demand concentrates in movements over subjects and mediums | **CONFIRMED-WITH-CORRECTION** | Painting-relevant movements draw 5–10× the lookup of subject genres (Impressionism 466K vs portrait 57K), and autocomplete completes movement+"paintings" naturally. Correction 1: the margin is inflated — Renaissance/Romanticism pageviews include non-painting interest. Correction 2: subject demand is real but phrased by depicted content ("paintings of jesus / flowers / women"), not by taxonomy terms. Correction 3: medium is a **maker's** axis — its completions are "classes near me" and "paint set", not browsing |
| C3 | Tondo's shipped facets cannot answer the top themes | **YES** | The top demand axis (movement) has no facet at all. The genre facet covers 248/2,000 works and has no value for flowers ("paintings of flowers" is a top-3 autocomplete; 148 probe candidates sit unlabeled). The pool's deepest holdings — Mughal 102, Rajput 102, Pahari 84, Chinese 180, Japanese 276 works — are invisible behind free-text `culture` strings while drawing 24K–68K annual lookups each |
| C4 | The pool can supply the top themes from data it already carries | **YES — and this overturns 0022's pessimism in three places** | 0022's dry run measured ONE route (museum tags) and found a 15–20% ceiling. Three unmeasured routes: medium strings are 100% present (oil 922, ink 761, tempera 457); culture strings name traditions for ~700 works; artist P135 reaches **70.5% of works in the top-80-artist sample** (vs the 6.2% the dry run got from the 200-name QID list alone) |

**Net effect:** the demand story and the supply story point at the same place from
opposite directions. Readers look up movements and named traditions; the pool's data
already carries traditions (culture strings) and can carry movements (P135, behind a
reconciliation job that `IDEAS.md` already holds). The shipped genre facet is real but
aimed at the smallest-demand vocabulary on the board, filled by the narrowest route.

---

## 2. What was done

Run 2026-08-20. Four tracks.

1. **Dictionary.** Wikidata SPARQL for instances of *art movement* (Q968159, 413
   candidates with an enwiki article), *art genre* (Q1792379, 215), *painting
   technique/material* (Q1231896 ∪ Q3300034, 73). Sitelinks as the notability prior
   (0007's method). **40 force-adds** where the class queries missed obvious painting
   vocabulary — Landscape painting, History painting, Rococo, and the pool's own
   strengths (Mughal/Pahari/Kalighat painting, hanging scroll, byōbu). Every force-add
   is flagged in the data.
2. **Recognition measurement.** English-Wikipedia pageviews, monthly, 2025-08 → 2026-07
   summed — same window and endpoint as 0007. Top 100/100/60 per axis by sitelinks plus
   the force-adds: 296 measured, 0 not-found.
3. **Venue corroboration.** Google autocomplete, 26 prefixes across the three axes plus
   an **artist-axis control** (0007 established artist demand; the control anchors the
   phrasing comparison). Reddit: dead — see §0; all 30 calls recorded as failures in
   the data file.
4. **Pool mapping.** Local analysis of the committed manifest: shipped genre counts, a
   title/description keyword probe over the 1,752 genre-nil works, medium-string
   normalization, tradition extraction from culture/country/department, the shipped
   century facet — plus a network estimate of the movement ceiling: top 80 attributed
   artist strings (353 works) resolved to QIDs and batch-queried for P135.

Raw data: `data/0008-candidates.json`, `data/0008-pageviews.json`,
`data/0008-venues.json`, `data/0008-pool-coverage.json`,
`data/0008-movement-ceiling.json`, `data/0008-recognizable-themes.json` (the merged,
adjudicated list). Reproduction in the appendix.

---

## 3. Track results

### 3.1 The rankings — kept themes, with what the pool holds today

**Movement axis** (31 kept, 10 rejected, tail unadjudicated). Pool column = works
reachable via artist P135 in the top-80-artist sample, except where noted.

| Theme | Pageviews 12mo | Pool works | Route |
|---|---:|---:|---|
| Renaissance | 1,104,748 | ~242 | period proxy (15th–16th c.) |
| Romanticism | 712,161 | 19 | artist P135 (sample) |
| Impressionism | 466,439 | 83 | artist P135 (sample) |
| surrealism | 445,586 | ~0 | walled (20th c.) |
| Baroque | 443,183 | 9 | artist P135 (sample) |
| Rococo | 349,311 | 11 | artist P135 (sample) |
| ukiyo-e | 305,789 | ~18 | culture strings (Edo) |
| cubism | 301,547 | ~0 | walled (20th c.) |
| Expressionism | 228,657 | 18 | artist P135 (sample) |
| Neoclassicism | 216,172 | 21 | artist P135 (sample) |

Also in the sample's supply: Post-impressionism 33, Hudson River School 29, French
Realism 23, Symbolism 19, Neo-impressionism 14 works. The pool's movement supply lives
almost entirely in the 19th century — the same era-wall shape as 0007's artists (46 of
200 born in the 20th century, where CC0 stops).

**Genre/subject axis** (39 kept, 15 rejected):

| Theme | Pageviews 12mo | Pool works | Route |
|---|---:|---:|---|
| ukiyo-e | 305,789 | ~18 | culture strings |
| Allegory | 239,685 | 0 shipped | GenreTerms value exists, no works carry it |
| nude | 190,660 | 3 | shipped genre (+11 probe) |
| Illuminated manuscript | 154,730 | ~52 kin | culture strings (Jain/Gujarat) |
| Icon | 120,277 | 25 kin | Religious Art value |
| still life | 118,754 | 15 | shipped genre (+27 probe) |
| vanitas | 117,882 | not measured | — |
| **Madhubani art** | **71,927** | **0** | **pool has none — Kalighat ≠ Madhubani** |
| Mughal painting | 67,575 | 102 | culture strings |
| portrait | 56,814 | 113 | shipped genre (+163 probe) |
| Chinese painting | 54,601 | 180 | culture strings |
| Landscape painting | 51,492 | 76 | shipped genre (+210 probe) |
| Persian miniature | 51,170 | ~19 | culture strings |
| Thangka | 49,234 | ~24 | culture strings (Tibet/Nepal) |
| History painting | 36,766 | 0 shipped | value exists, no works |
| Kalighat painting | 27,733 | 44 | culture strings |
| Pahari painting | 24,013 | 84 | culture strings |

Erotic art (214K) and shunga (208K) are kept on the list and unservable by this pool —
the walled-fraction principle from 0007: names that cannot be filled stay visible.

**Medium axis** (24 kept, 6 rejected):

| Theme | Pageviews 12mo | Pool works |
|---|---:|---:|
| fresco painting | 196,776 | 2 |
| gouache paint | 159,094 | 8 |
| oil painting | 126,413 | 922 |
| acrylic paint | 86,688 | 1 |
| watercolor | 86,509 | 56 |
| Gold leaf | 71,584 | 484 |
| ink wash painting | 68,856 | 761 |
| Pastel | 61,432 | 0 |
| Byōbu (folding screen) | 19,810 | 83 |
| Hanging scroll | 13,200 | 193 |

The mismatch runs both directions: the pool is deepest in mediums nobody looks up
(tempera 457 works / 1.5K pageviews) and near-empty in mediums people do (acrylic 87K
lookups / 1 work — a modern-era medium, walled by construction).

### 3.2 Deciding what counts as a theme — the serial-killer problem again

0007's Wikidata "painter" list was topped by John Wayne Gacy. This run's raw class
queries were topped by: **rapping** (art movement, 310K), **Britpop** (movement),
**bohemianism** (movement), **vaporwave** and **solarpunk** (art genres), **ASCII art**
(genre), **shellac** and **dragon's blood** (painting materials), **fiction** and **the
art of sculpture** (genres, 132K–163K). 31 head-of-list rejects across the axes, each
with its reason in `data/0008-recognizable-themes.json`; the rule is "a theme a reader
could browse *paintings* by," and it was applied by hand, not by regex.

Two systematic corrections the force-adds exposed:

- **Wikidata's `art genre` class does not contain the canon of painting genres.**
  Landscape painting, History painting, Genre painting, Portrait painting — absent as
  instances. The measured list would have missed the four most canonical genres in
  Western art while including vaporwave. Same failure family as 0007's occupation
  blocklist deleting Leonardo.
- **Named non-Western traditions live in no queried class at all.** Mughal, Pahari,
  Kalighat, Madhubani, shan shui, thangka — none arrived via SPARQL; all were
  force-added, all turned out to draw 15K–72K annual lookups. An instrument built only
  from Wikidata's Western-leaning class tree would have called the pool's deepest
  holdings demand-free.

### 3.3 Venue phrasing — which axis do seekers actually speak?

Autocomplete, artist control included (full table in `data/0008-venues.json`):

| Prefix | Completions |
|---|---|
| "impressionist pain" | impressionist **paintings**, painters, paintings for sale, painting style |
| "baroque paint" | baroque painting, painters, **paintings of women** |
| "paintings of" | **jesus, flowers, hell, women** |
| "still life paint" | still life painting, ideas, meaning, **paintings by famous artists** |
| "mughal paint" | mughal paintings, **for sale**, painting style, **of women** |
| "oil paint" | oil painting, **classes near me, paint set, oil paint vs acrylic** |
| "watercolor paint" | watercolor painting, **paint set, for beginners, classes near me** |
| "tempera" | temperature (nothing art-related at all) |
| "van gogh paint" (control) | van gogh paintings, price, for sale, style |

Three phrasing facts fall out:

1. **Movement + "paintings" is a natural query** — every movement prefix completed to
   a plural-paintings browse form, the same shape as the artist control.
2. **Subject demand is phrased by depicted content, not by genre taxonomy** — nobody
   completes to "genre painting"; they complete to *paintings of jesus / flowers /
   women*. A subject facet that speaks taxonomy ("Genre Scene") answers a question
   nobody asks in those words.
3. **Medium prefixes belong to people who paint, not people who look** — supplies,
   classes, beginners. The one exception shape: East-Asian formats (scroll, screen)
   read as *kinds of object* rather than techniques.

### 3.4 The movement ceiling — 0022's 6.2% was a floor, not a ceiling

`specs/0022`'s dry run measured Route 1 (P135 through the 200-name 0007 QID list) at
124/2,000 works and priced full reconciliation as "a research project the size of the
0007 list." This run sampled that unpriced space: the top 80 attributed artist strings
(353 works; placeholders like "China" and "French Painter" excluded by the
`NOT_AN_ARTIST` shape), resolved by search to QIDs, batch-queried for P135.

- **249 of 353 sampled works (70.5%) have an artist with a real P135 movement claim.**
- 7 of 80 resolutions were wrong (a Hudson River School painter resolved to an
  ophthalmologist) — all 7 returned empty P135, so the true sample rate is **at least**
  70.5%.
- The frame biases the other way too: top artists are the most-reconciled artists. The
  617 placeholder-attributed works have no P135 route at all — but those are largely
  the same works the tradition route (§3.5) reaches instead.
- The two routes are complements, not rivals: P135 covers the attributed Euro-American
  half; culture strings cover the anonymous Asian half.

### 3.5 What the pool is secretly deep in

Culture/country/department regex over the manifest (counts are works):

| Tradition | Pool works | 12-mo pageviews |
|---|---:|---:|
| Japanese painting | 276 | 27,690 |
| Chinese painting | 180 | 54,601 |
| Mughal painting | 102 | 67,575 |
| Rajput painting | 102 | 18,611 |
| Pahari painting | 84 | 24,013 (+ Kangra 15,309) |
| Jain manuscript tradition | 52 | (via Illuminated manuscript, 154,730) |
| Kalighat painting | 44 | 27,733 |
| Korean painting | 32 | — |
| Tibetan/Nepalese (thangka kin) | 24 | 49,234 |
| Persian/Islamic | 19 | 51,170 |

**~700 works — 35% of the pool — carry a nameable tradition in their culture strings
that no shipped facet can express.** This is persona 3's verbatim ask ("she wants Benin
bronzes, **Mughal miniatures, ukiyo-e**") sitting in data the app already stores. The
0013/0019 range work put these works *in* the pool; nothing yet makes them *findable*
as what they are.

### 3.6 Genre headroom via title keywords — the route 0022 never measured

Keyword probe over title + description of the 1,752 genre-nil works (candidates, not
fills — every count needs adjudication before anything writes to the column):

Religious 302 · Landscape 210 · Animal 192 · Portrait 163 · **Flowers 148** · Still
Life 27 · Mythological 24 · Genre Scene 17 · Marine 12 · Nude 11 · Cityscape 1.

Two things matter. First, magnitude: adjudicated even at half yield, the genre facet
goes from 248 works to ~600–900. Second, **reach**: titles exist on every work, so this
route reaches the CMA/MIA 80% of the pool that 0022 correctly wrote off for museum-tag
routes. The dry run's "15–20% ceiling" was a ceiling on one route, not on the facet.
(The Animal count is the noisiest — bird/lion words fire inside religious and landscape
titles; treat it as an upper bound on candidates, not a fill estimate.)

---

## 4. Claim-by-claim adjudication

- **C1 — ranking buildable: CONFIRMED.** 296 measured, 0 retrieval failures, steep
  stable distribution. Cost of admission: 31 hand-rejects and 40 force-adds; the raw
  class queries alone would have produced a list with vaporwave and without Landscape
  painting.
- **C2 — movements dominate: CONFIRMED-WITH-CORRECTION.** Quantitatively yes at 5–10×,
  but the pageview instrument inflates umbrella movements (Renaissance reads as a
  history topic), subject demand hides in "paintings of X" phrasing that no taxonomy
  term captures, and medium "demand" is mostly painters shopping for supplies. The
  corrected order for a *browsing reader*: movements/traditions first, depicted-subject
  second, medium last (formats excepted).
- **C3 — shipped facets can't answer: CONFIRMED.** No movement facet; genre facet at
  12.4% coverage aimed at taxonomy vocabulary; traditions invisible; centuries are an
  era proxy no seeker types.
- **C4 — pool can supply: CONFIRMED**, via three routes 0022 never measured (medium
  strings 100%, culture strings ~35%, sampled P135 ≥70% of attributed-top works), with
  the walled exceptions named: surrealism/cubism/abstract-expressionism (movement),
  erotic art/shunga (genre), acrylic/pastel (medium), Madhubani (tradition — a
  collection gap, not a copyright wall).

---

## 5. New findings

- **N1 — The biggest demand axis has zero product surface and a cheaper path than
  believed.** Movements out-draw every other vocabulary; P135 reaches ≥70% of
  top-artist works, not 6.2%. *So what:* the deferred "P135 fill" idea in `IDEAS.md`
  is under-scoped as a genre patch — its real payoff is a movement facet, and it
  shares its hard part (artist reconciliation) with the canonicalisation idea already
  queued there.
- **N2 — A title/description keyword route reaches the 80% of the pool museum tags
  can't**, with ~600–900 adjudicated works plausible against 248 today. *So what:*
  genre-fill v2 needs no new external dependency at all.
- **N3 — ~35% of the pool is nameable non-Western tradition sitting in free-text
  culture strings** (Mughal 102, Rajput 102, Pahari 84 …), each drawing real lookup.
  *So what:* the single cheapest demand-supply match on the board — a mapping table
  over data already stored, serving the persona the range work was done for.
- **N4 — Medium is a maker's axis, not a viewer's.** Every medium prefix completes to
  supplies and classes; tempera (457 works) draws 1.5K lookups. *So what:* a
  viewer-facing medium facet is weak; East-Asian formats (hanging scroll 193, screen
  83) are the exception worth folding into the tradition vocabulary instead.
- **N5 — Subject demand speaks depicted content: "paintings of jesus / flowers /
  women / hell."** Flowers: 148 candidate works, no facet value, top-3 completion.
  *So what:* a Flowers value (bird-and-flower kin included) is the one clear addition
  demand makes to the existing genre vocabulary.
- **N6 — ukiyo-e is the single most-demanded theme the pool nearly cannot serve**
  (306K lookups; ~18 Edo-period paintings — the genre is mostly woodblock prints,
  which the paintings-only pool excludes by construction). *So what:* an honesty case,
  not a fill case; a facet may still clear `MIN_FACET_WORKS`, but the label carries
  more expectation than 18 works satisfy.
- **N7 — The Reddit archive era is over for this project.** pullpush now refuses
  automated access explicitly; arctic-shift throttles. *So what:* future
  corroboration needs a different instrument (the gallery runs are now the only
  behavioral check), and 0007's corpus is irreplaceable as collected.

---

## 6. Consequences — evidence, not decisions

Options this evidence supports, cheapest first. The decision belongs in `decisions/`,
not here; nothing below is baseline work without a spec (CLAUDE.md build flow).

1. **Tradition values through the existing genre machinery** (N3): a hand-checked
   mapping from culture-string patterns to canonical values (Mughal Painting, Pahari
   Painting, Kalighat Painting, Chinese Painting, Japanese Painting …). Reuses the
   shipped facet UI, floor, and URL scheme; ~700 works; no external dependency; serves
   Amara's verbatim ask.
2. **Genre-fill v2 via adjudicated title keywords** (N2, N5): 248 → ~600–900 works,
   reaches CMA/MIA, adds Flowers. The probe dictionary in
   `scripts/0008/pool_coverage.py` is the starting candidate list, not the fill.
3. **Movement facet riding the reconciliation story** (N1): highest demand, highest
   cost — it needs the artist-canonicalisation + QID work `IDEAS.md` already queues,
   and 0022's eng review already priced the SPARQL client honestly. The two queued
   ideas plus this evidence are one story, not three.
4. **No viewer-facing medium facet** (N4): the demand shape argues against spending
   the facet budget here; scroll/screen formats fold into option 1's vocabulary.

**Wrong-if line (falsifiable, time-bound, free instrument):** the next gallery run
(`user-research/0006` protocol — it already counts theme-seeking as a denominator) is
the check. This ranking is **wrong if**, among participants who seek a theme at all,
their asks phrase as mediums or as taxonomy terms ("genre painting") rather than as
movements, traditions, or depicted subjects — or if a shipped tradition/movement facet
draws zero unprompted taps across a full run of ≥5 participants. Either result reopens
C2 with observed behavior against looked-up behavior, and observed wins.

---

## 7. Limitations — read before using any number

1. **One quantitative instrument.** Reddit corroboration is dead (§0); the ranking
   rests on pageviews plus autocomplete phrasing. 0007 had two instruments disagree
   usefully; this run cannot.
2. **Pageviews measure looking-up, not browse intent** — and the error is not uniform
   across themes: Renaissance/Romanticism/Bauhaus carry heavy non-painting interest;
   Icon carries software-icon noise. Cross-axis ratios (C2) are directional, not
   precise.
3. **Autocomplete is unquantified and locale-shaped.** Completions prove existence and
   phrasing only; builder searches inflate them; results vary by region.
4. **The QID resolution in the movement sample is first-hit search, not the 0019
   collision-aware matcher.** 7/80 provably wrong (all deflating). The 70.5% is a
   sample statistic on a frame (top-80 attributed artists) that over-represents
   reconcilable artists; the attributed tail (771 strings, 1,030 works) is unmeasured.
5. **Tradition counts come from regex over free-text culture strings**, unvalidated
   row-by-row ("Rajasthan" may catch non-Rajput works; "Japan" catches every Japanese
   work regardless of school). Counts are ±, suitable for sizing, not for a facet fill
   without the same adjudication the genre probe needs.
6. **The keyword probe over-triggers** (Animal 192 includes religious works with lions
   in them). Every probe number is a candidate ceiling, not a yield.
7. **Rights were assessed only qualitatively on this axis** — "walled (20th c.)" on a
   movement is a judgment from 0007's era finding, not a per-work count.
8. **A dictionary instrument cannot rank a theme it never measured.** The candidate
   set is Wikidata classes + 40 hand adds; a vocabulary readers use that neither
   contains (a color? a mood? "dark academia"?) is invisible here. The gallery-run
   denominator is the catch-all.

---

## Appendix: reproduction

Scripts, in run order, committed under `user-research/scripts/0008/`. All re-runnable.

```
candidates.py         Wikidata SPARQL, 3 classes → 0008-candidates.json (701 candidates)
pageviews.py          top 100/100/60 by sitelinks + 40 force-adds → 0008-pageviews.json
                      (296 measured, window 2025080100–2026080100, agent=user)
venues.py             Google autocomplete (26 prefixes) + Reddit attempts (all refused,
                      recorded) → 0008-venues.json
pool_coverage.py      manifest analysis: shipped genre, keyword probe, medium
                      normalization, traditions, period facet → 0008-pool-coverage.json
movement_ceiling.py   top-80 artist sample → wbsearchentities → batched P135 SPARQL
                      → 0008-movement-ceiling.json
build_list.py         merge + hand adjudication (verdict per head-of-list theme)
                      → 0008-recognizable-themes.json
```

APIs: `query.wikidata.org/sparql`, `wikimedia.org/api/rest_v1/metrics/pageviews/
per-article/en.wikipedia/all-access/user/<TITLE>/monthly/2025080100/2026080100`,
`en.wikipedia.org/w/api.php` (redirect + QID resolution),
`suggestqueries.google.com/complete/search?client=firefox`.
Pool inputs: `db/seeds/paintings.json` (committed manifest, 2,000 works),
`storage/development.sqlite3` (period facet), `app/models/painting.rb` NOT_AN_ARTIST
(placeholder shape). Prior work consumed: `user-research/0007` (method, QID list),
`specs/0022-what-kind-and-when/plan.md` (dry-run numbers corrected here).
