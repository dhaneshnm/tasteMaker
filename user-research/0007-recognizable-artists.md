# Recognizable Artists: who a visitor actually goes looking for

**Project:** Tondo (Month 1, 12-month experiment, Fork B)
**Date:** 2026-08-19
**Purpose:** Produce the ranked list of lay-recognizable artists that `specs/0019-the-coverage-fill`
consumes, and measure how much of it four CC0 museum collections can actually supply.
**Status:** Research document. No go/no-go authority — kill review stays 2026-08-31 against `BET.md`.
Any direction change this triggers belongs in `decisions/`.

---

## 0. The instrument that ran is not the instrument that was planned

`specs/0018-the-names-you-know/plan.md` step 7 specified: mine Reddit for unprompted artist
mentions, **rank by mention frequency**, and cross-rank against Wikipedia pageviews as the
control. That is not what happened, and the swap is the first thing a reader needs.

Both Reddit archives — pullpush and arctic-shift — began returning `429` and timeout errors
partway through collection and did not recover. The corpus finished at **871 documents**
against report `0002`'s 5,311. At that size the top real artist has **six** mentions and the
long tail is all ones, which cannot order 200 names.

So the two instruments swapped roles:

| | Planned | Actual |
|---|---|---|
| **Primary ranking** | Reddit mention frequency | **English-Wikipedia pageviews, 2025-08 → 2026-07** |
| **Independent check** | Wikipedia pageviews | **Reddit mentions across five art subreddits** |

This is a weaker report than the plan asked for, and the ranking below should be read as
"how many people look this artist up", not "how many people talk about this artist." The two
are not the same claim. Pageviews are arguably the better proxy for the actual question —
a visitor searching Tondo for a name they know is doing the same thing as a person typing
that name into Wikipedia — but that is a rationalisation after the fact, not the design.

---

## 1. Executive verdicts

| # | Claim | Verdict | Decisive evidence |
|---|---|---|---|
| C1 | A stable ranking of "recognizable artist" can be built at all | **YES** | 800 painters measured, 784 returned 12-month pageviews. The distribution is steep and sensible: van Gogh 2.00M, Kahlo 1.95M, Michelangelo 1.16M, down to 27.6K at rank 200 |
| C2 | Wikidata "occupation: painter" is usable as-is | **NO — and this is the load-bearing correction** | Ranked by raw pageviews, the top of the list is a serial killer (John Wayne Gacy, 5.42M), Freddie Mercury (5.22M), Paul McCartney (4.49M) and George W. Bush (4.34M). All four are Wikidata painters. **356 of 556 candidates were rejected** |
| C3 | Reddit corroborates the pageview ranking | **PARTIALLY, and the corpus is too thin to say more** | Only **86 of the 200** appear in 871 documents at all. Where both fire they agree on the obvious (van Gogh, Kahlo, Klimt, Monet, Vermeer). 20 names are pageview-inflated, 19 Reddit-inflated. No rank correlation is reported: at these counts it would be noise dressed as a statistic |
| C4 | The lay subreddits and the expert subreddits want the same artists | **UNRESOLVED** | Directionally different — lay (r/Art, r/painting, r/ArtPorn) surfaces Kahlo, Courbet, Klimt, van Gogh; expert (r/ArtHistory, r/museum) surfaces Francis Bacon, Escher, Magritte, Vermeer, Fragonard. With 871 documents this is a hint, not a finding |
| C5 | CC0 museum sources can supply the list | **NO — only 53% of it is reachable at all** | Of 200 names: **73 already in the pool, 32 fillable, 21 absent, 74 walled**. 105 of 200 are reachable in principle; 95 are not, at any effort |
| C6 | The copyright wall is the main reason a name is missing | **YES, and it is the dominant one** | 74 walled against 21 absent-but-public-domain. Recognition is heavily modern — 46 of the 200 were born in the 20th century — and that is exactly where CC0 public-domain sources stop |

**Net effect on story 0019:** the fill has real headroom — 32 names the mirrors hold and the
pool does not — and a hard ceiling at 105 of 200. The story's success signal is stated against
the reachable subset for that reason: a target expressed over all 200 would be unreachable by
construction and would measure copyright law rather than curation.

---

## 2. What was done

Run 2026-08-19. Four tracks.

1. **Dictionary.** Wikidata SPARQL for humans with occupation painter / artist / printmaker
   holding an English Wikipedia article: **65,626 painters** with label, sitelink count, birth
   and death years. A companion alias dump returned 227,175 aliases — but see §4, it was
   truncated and had to be re-fetched for the final list.
2. **Recognition measurement.** English-Wikipedia pageviews, monthly, 2025-08 → 2026-07,
   summed to a 12-month total, for the **top 800 painters by sitelink count** (sitelinks as
   the notability prior that decides who is worth measuring). 784 returned data.
3. **"Is this person a picture-maker" filter.** Wikidata's one-line English description for
   each of the 800, and a positional rule over it: keep when the **earliest role noun in the
   description is an art noun**. See §3.2 — two earlier filters were built, measured and
   thrown away before this one.
4. **Reddit corroboration.** r/Art, r/painting, r/ArtHistory, r/museum, r/ArtPorn via the
   pullpush and arctic-shift archives (Reddit blocks crawlers; this is report `0002`'s
   method). **871 documents.** Matched against the dictionary by full name and alias, with a
   bare surname counted only when exactly one dictionary painter has it, it is ≥ 5 characters,
   it is not an ordinary English word, and that painter has ≥ 25 sitelinks.

Raw data: `data/0007-recognizable-names.json` (the list), `data/0007-artist-mentions.json`
(mention counts and example snippets), `data/0007-pageviews.json` (the recognition
instrument), `data/0007-corpus.json` (every Reddit document). Reproduction in the appendix.

---

## 3. Track results

### 3.1 The list

200 names. Rank is 12-month English-Wikipedia pageviews.

| # | Name | Pageviews | Reddit | Rights |
|---:|---|---:|---:|---|
| 1 | Leonardo da Vinci | 2,153,996 | 2 | public domain |
| 2 | Yoko Ono | 2,072,449 | 0 | walled |
| 3 | Vincent van Gogh | 2,002,895 | 5 | public domain |
| 4 | Frida Kahlo | 1,946,048 | 5 | walled |
| 5 | Banksy | 1,860,156 | 0 | walled |
| 6 | Pablo Picasso | 1,790,840 | 4 | walled |
| 7 | Andy Warhol | 1,653,972 | 2 | walled |
| 8 | Jean-Michel Basquiat | 1,355,062 | 1 | walled |
| 9 | Michelangelo | 1,160,740 | 0 | public domain |
| 10 | Salvador Dalí | 1,088,991 | 1 | walled |

The tail is not filler: rank 200 (Masaccio) still draws **57,091** annual pageviews.

**Era spread**, by birth century: 13th 1, 14th 4, 15th 13, 16th 16, 17th 5, 18th 23,
**19th 91, 20th 46**. That shape is the whole problem this report hands to story 0019.
Recognition lives in the last two centuries, and the 20th century is precisely where CC0
public-domain sources stop — which is why 93 of the 200 come back `walled`. It is also the
pressure Amara's guard rail exists to resist: a fill that chased this ranking without a
region quota would drag the pool toward exactly the modern Euro-American canon persona 3
complains about.

### 3.2 Deciding who counts as an artist — two failed instruments and the one that worked

Ranked on pageviews alone, before any filter, the top four Wikidata "painters" are a serial
killer, a rock singer, a Beatle and a US president. Something has to decide who is a
picture-maker. Three instruments were built; the first two are recorded because they nearly
shipped and both were wrong in ways that are only visible once you look at the output.

**Attempt 1 — blocklist of occupations (`P106`).** Reject anyone holding any of
{actor, politician, photographer, composer, mathematician, …}. It deleted, in one pass:

| Deleted | Because Wikidata also lists them as |
|---|---|
| Leonardo da Vinci | mathematician |
| Pablo Picasso | photographer |
| Andy Warhol, Banksy | film director |
| Salvador Dalí | actor |
| Jean-Michel Basquiat | composer |
| Rembrandt, Vermeer | art collector |
| Michelangelo, Rembrandt, El Greco | architect |

Great artists accumulate occupations. The rule was measuring breadth of career and calling
it "not an artist."

**Attempt 2 — any strong art noun anywhere in the description keeps you.** This let in
Hermann Hesse ("poet, novelist and painter"), Grace Slick ("musician, writer and painter"),
Zaha Hadid ("architect, designer and painter") and B. R. Ambedkar ("polymath, philosopher,
and social reformer" — "polymath" had been added for Leonardo).

**Attempt 3 — the earliest role noun wins.** Wikidata descriptions put the primary role
first, and that turns out to be the whole signal: *"Spanish painter and sculptor"* is a
painter; *"American musician, writer and painter"* is a musician. The rule keeps Leonardo
(force-kept — Wikidata calls him only a "polymath"), Picasso, Warhol, Dalí, Basquiat, Banksy
and Keith Haring, and rejects Gacy, Mercury, McCartney, Bush, Bowie, Dylan, Carrey and Walt
Disney. **356 rejections**, each carrying the description that decided it.

**13 names were hand-adjudicated** where no rule could reach them, each with its reason in
the data file. Three worth quoting:

- **Joseph Merrick** — the Elephant Man. Wikidata's only occupation for him is "artist," for
  a cardboard church he built in hospital.
- **Bob Ross** — a genuine painter and genuinely recognizable (1.51M pageviews), rejected
  because no museum collects him: he can never be filled, so reporting him as a gap would be
  reporting a gap that cannot close.
- **Stuart Sutcliffe** — his own description says "better known as the original bass
  guitarist of the Beatles." The pageviews are the band's.

### 3.3 Divergence between the two instruments — flagged, never averaged

**20 pageview-inflated** names: looked up constantly, absent from 871 documents of Reddit art
talk — Michelangelo, Rembrandt, Raphael, Goya, Pollock, Diego Rivera, Yoko Ono, Banksy.
These are the P2 case exactly: canonical enough that nobody posts about them and a visitor
still expects to find them. **They are kept.**

**19 Reddit-inflated** names: talked about well above their pageview rank — Gustave Courbet,
Bouguereau, Malevich, Tamara de Lempicka, Albert Bierstadt, Fragonard, Odilon Redon,
Tintoretto. Read as a subreddit-community signal rather than lay recognition, and kept
at their pageview rank rather than promoted.

### 3.4 What four CC0 collections can supply

Measured by `bin/rails pool:coverage` against the committed manifest and the 2026-08-13/18
mirrors of the Met, the Art Institute of Chicago, Cleveland and Minneapolis:

| Bucket | Names | |
|---|---:|---|
| `covered` | 73 | already in the shipped pool |
| `fillable` | 32 | mirrors hold a qualifying work, pool does not |
| `absent` | 21 | public domain, not held by these four as a qualifying painting |
| `walled` | 74 | in copyright |
| `fails_bars` | 0 | held but every candidate fails a 0013 bar |

**Reachable coverage before the fill: 69.5%** (73 of 105). After story 0019's fill ran:
**100.0%** (105 of 105) — every name these four collections can supply is now in the pool.

The 32 fillable names included some the pool had no excuse for: **Katsushika Hokusai (16
qualifying works available), Frans Hals (16), Sandro Botticelli (8), Utagawa Hiroshige (8),
Canaletto (8), Jacopo Tintoretto (5)**. Several were **provisional** — their only
candidates are Met rows, and the Met CSV carries no plate URL or dimensions, so whether a
photograph exists is knowable only at selection time.

---

## 4. Limitations — read these before using any number above

1. **The Reddit corpus is 871 documents, not the several thousand the method assumes.** Both
   archives rate-limited mid-collection. Every mention count is a floor, and the absence of a
   name from the Reddit column means almost nothing.
2. **Reddit is not a sample of App Store readers** in any case. It is a prior about which
   names are live in public art talk, not a measurement of Tondo's audience — which is zero
   people, because the binary has never been uploaded.
3. **Pageviews measure looking-up, not liking.** A spike can be a film, an anniversary or a
   theft. Monthly data over 12 months damps this; it does not remove it.
4. **A dictionary-match instrument cannot find an artist who is not in the dictionary**, and
   the dictionary is Wikidata's idea of a painter — which, as §3.2 shows, is broad in one
   direction and arbitrary in another.
5. **The alias dump was truncated and nearly silently damaged the result.** The bulk SPARQL
   returned aliases for 37,059 of 65,626 painters, missing exactly the famous ones — van Gogh,
   Leonardo and Velázquez all came back with none. Aliases are load-bearing: they are the
   difference between finding **0** Goya works and **29**. The final 200 had their aliases
   re-fetched directly. Any earlier number computed from that dump is wrong.
6. **No nationality split is reported, and one was attempted.** Wikidata citizenship for
   historical artists resolves to defunct states (Holy Roman Empire, Duchy of Urbino, the
   Seventeen Provinces), and a hand-built Western/non-Western classifier put **Raphael,
   Turner, van Eyck and Constable in the non-Western bucket**. The number was discarded rather
   than published. The range guarantee for the pool does not live here anyway — it lives in
   `Pool::Curator`'s region quota, which `verify!` enforces on every curation.
7. **The `rights` field is a rule, not a lawyer.** `public_domain` if the artist died before
   1931 (US: 95 years from publication, evaluated in 2026), `walled` otherwise. It errs toward
   `walled`, which is the direction that cannot invent a false collection gap.

---

## 5. What this feeds

`specs/0019-the-coverage-fill` consumes `data/0007-recognizable-names.json` directly:
`Pool::Recognizable` reads it, resolves each name to the set of museum artist strings it can
legitimately claim (canonical spelling, Wikidata aliases, and the museums' own
parentheticals), and `Pool::Curator#fill_recognizable` takes up to three works per name
*before* any other selection stage runs.

Two things this report settles for that story:

- **The fill has somewhere to go.** 32 names, including Hokusai at 16 available works. It
  went there: coverage of the reachable set moved 69.5% → 100%.
- **The ceiling is 105 of 200, and it IS mostly copyright — but not entirely.** 74 walled
  against 21 public-domain-but-not-held. Folding those together would have blamed CC0
  licensing for what is, for 21 names, simply a gap in four American collections.

The names that cannot be filled are not deleted from the list. Keeping Picasso, Kahlo, Dalí,
Warhol and Basquiat on it is what makes the walled fraction measurable instead of invisible.

---

## Appendix: reproduction

Scripts, in run order, committed under `user-research/scripts/0007/`. All are re-runnable.

```
sparql.py          Wikidata → raw_core.jsonl (65,626 painters), raw_alias.jsonl
pageviews.py 800   top 800 by sitelinks → pageviews.json  (12-month totals)
occupations.py     P106 for those 800 → occupations.json
mine_slow.py       pullpush/arctic-shift → corpus.jsonl   (871 docs; rate-limited)
merge_all.py       salvage every collector's documents into one deduped corpus
match.py 8         corpus × dictionary → mentions.json    (mention counts)
build_list.py      rank, filter, adjudicate → recognizable-names.json
fix_aliases.py     re-fetch complete aliases for the final 200
citizenship.py     P27 for the final 200 (raw values retained; no split published — §4.6)
```

Then, in the app:

```
bin/rails pool:coverage    # the before/after number, from committed files only
```

Pageview API: `https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/en.wikipedia/all-access/user/<TITLE>/monthly/2025080100/2026080100`
