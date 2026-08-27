# 0028 — Plan

No design review, no eng review (owner: "no reviews required" for this story). Executed
in one pass.

## Steps

1. **Cross-check the research artifact against `lib/pool/sources.rb` and
   `specs/0013`'s banned-source list**, to find what subset of "100 recognizable
   paintings" this app could legitimately ingest at all. Result: only the Met/AIC/CMA-
   sourced rows qualify; NGA/Getty/Rijksmuseum/Smithsonian aren't mirrored, Wikimedia
   rows are banned outright.
2. **Diff the qualifying artist names against `user-research/data/0007-recognizable-
   names.json`** by name/alias. 41 of 54 already present. Nine genuinely new: Gilbert
   Stuart, George Catlin, John Singleton Copley, Georges de La Tour, George Bellows,
   Rembrandt Peale, Thomas Moran, Jan Steen, Emanuel Leutze.
3. **Fetch real data for the nine**, same instruments the 0007 build script uses —
   Wikidata SPARQL (QID, English Wikipedia title, aliases, birth/death year) and the
   Wikipedia pageviews REST API (12-month view count) — rather than hand-typing values
   into a research file that carries real mined data everywhere else. One name,
   "Pieter Bruegel the Elder," didn't resolve on the first SPARQL label match and was
   dropped rather than guessed at.
4. **Append nine rows** (rank 201–209) to the committed 0007 JSON. `rights:
   public_domain` for all nine — every one died before the file's own US_CUTOFF = 1931
   rule, same branch `build_list.py` would take. Reddit-mention mining
   (`mine_slow.py`) was **not** re-run for nine names — `mentions: 0`, `by_subreddit:
   {}`, `divergence: null`, which is the same value the real pipeline writes for any
   name with no corpus hits, so this isn't a fabricated field, it's an honestly-skipped
   one.
5. **`bin/rails pool:coverage`** — before/after numbers below.
6. **`bin/rails pool:curate`** against the cached mirrors (not re-fetched) — writes
   `db/seeds/paintings.json` + `db/seeds/pool_report.md`.
7. **`bin/rails test test/lib/pool_quota_test.rb`**, then full `bin/ci`.
8. **Verify prod directly**, read-only, before calling this shipped.
9. Commit, push, PR, merge (no review gate — owner said skip it), `SHIPLOG.md`.

## What the run actually found

`pool:coverage` at 209 names: **112 covered, 0 fillable, 23 absent, 74 walled — 100%
reachable coverage** (112 of the 112 names these four collections can actually supply).

Per-name detail for the nine, queried directly rather than assumed from the bucket
counts alone:

| Name | Bucket | Works already in pool | Works in the mirrors |
|---|---|---:|---:|
| Gilbert Stuart | covered | 5 (at `MAX_PER_ARTIST`) | 11 |
| John Singleton Copley | covered | 5 (at `MAX_PER_ARTIST`) | 9 |
| George Bellows | covered | 5 (at `MAX_PER_ARTIST`) | 5 |
| Rembrandt Peale | covered | 3 | 3 |
| Georges de La Tour | covered | 2 | 3 |
| Thomas Moran | covered | 2 | 2 |
| Jan Steen | covered | 2 | 7 |
| George Catlin | **absent** | 0 | 0 — not held by these four as a painting |
| Emanuel Leutze | **absent** | 0 | 0 in the *cached* mirror |

**Seven of nine were never actually missing.** The ordinary quota table (region/era/text
bars, no recognizable-name involvement) had already selected at least one work by each
of them into the 2,300-work pool — they were invisible to `pool:coverage` only because
they weren't on its input list, not because the pool lacked them. Re-running
`pool:curate` against this confirms it: **`db/seeds/paintings.json` came back byte-for-
byte identical, 0 works added, 0 removed.** The recognizable-name stage tops a name up
toward `DEPTH = 3` only when doing so doesn't cost a `MAX_PER_ARTIST`-capped or
otherwise-committed slot from elsewhere; here every candidate slot these nine could have
claimed was either already occupied by their own work or would have displaced a
different name at equal or higher priority. So: **success signal 2 resolved to "no
change," which is itself the falsifiable answer** — not a shortfall, a measurement that
the pool was already correct and the research list was the only thing behind.

**George Catlin is genuinely absent** — none of the four museums hold a Catlin painting
meeting the 0013 bars. Reported as `absent`, not `walled` (he died 1872, long public
domain) — an honest supply gap, not a rights gap.

**Emanuel Leutze is the one surprising result.** This session's live research (Met
`collectionapi.metmuseum.org`, object 11417, "Washington Crossing the Delaware")
confirmed `isPublicDomain: true` today. The *cached* Met mirror this pipeline reads
(`tmp/pool/met.json`, pulled 2026-08-13 from the Met's bulk GitHub CSV export) carries no
Leutze row at all — zero hits on the artist string, zero on the title. That's a
discrepancy between the Met's live object API and its bulk CSV export, not a rights
question. **Not chased further here** — `pool:mirror` wasn't re-run (story 0019 made the
same call, same reason: cost and determinism), and finding out whether the CSV is
genuinely missing the row or the row is filed under different metadata is its own,
separate investigation. Logged as a candidate `IDEAS.md` entry, not fixed in this story.

No bar regressed: `pool_quota_test.rb`, 27/27 green, including the recognizable-coverage
assertion. `bin/ci` green in full (unit/integration + 66 system tests).

## Deviations from the owner's original ask

The owner asked to "add this [the 100-painting research artifact] to our local and
prod." What shipped is the nine-name subset above, for three stated reasons, not silent
scope-cutting:

1. **~22 of the 100 rows have no legitimate source in this app at all** — Wikimedia
   Commons is a named-and-rejected ingest source (`specs/0013`). Adding them would mean
   either reopening that rejection without a `decisions/` entry, or shipping content
   this app's own settled rules forbid.
2. **~24 more rows come from museums this app doesn't mirror** (NGA, Getty,
   Rijksmuseum, Smithsonian). Wiring a fifth source is a real, reversible-but-not-small
   engineering decision — new fetcher, new rate limits, new region mapping — that
   deserves its own story and, per the stack rule, its own one-line `decisions/` reason.
   Not decided here.
3. **Of the remaining ~54 rows (Met/AIC/CMA-sourced, the sources this app already
   uses), 41 were already on the recognizable-names list** — the research independently
   rediscovered most of what story 0019 had already found. The nine real gaps are the
   entire addressable difference between "the owner's research" and "what story 0019
   already built."

No `decisions/` entry filed for this narrowing: it doesn't reopen a settled fact (Met/
AIC/Cleveland/Minneapolis stays the source list; Wikimedia stays rejected) or change
product direction — it's scope clarification inside an existing, already-decided
pipeline, which is exactly the kind of call R9 says gets executed, not escalated.

## Prod verification (receipt, not inference)

`kamal app exec --reuse "bin/rails runner"`, read-only, `artist LIKE '%name%'` per name,
run for real against the live container (`e18a6d0`, 34.59.147.140):

```
Gilbert Stuart: 5
George Catlin: 0
John Singleton Copley: 5
Georges de La Tour: 2
George Bellows: 4
Rembrandt Peale: 3
Thomas Moran: 2
Jan Steen: 2
Emanuel Leutze: 0
TOTAL: 2300
```

Bellows reads 4, not 5 — a query artifact, not a data gap, and the same 4-not-5 reproduces
locally against the identical manifest: one of the five Bellows works is attributed
`"George Wesley Bellows"`, which the substring `LIKE '%George Bellows%'` doesn't match
("Wesley" breaks the substring) but `Pool::Recognizable`'s real alias-aware matcher does.
Checked locally before trusting it — not assumed. Every number here matches the local
manifest exactly, as the 0-added/0-removed curate run predicted: prod was never behind,
it already held every one of the seven `covered` names.
