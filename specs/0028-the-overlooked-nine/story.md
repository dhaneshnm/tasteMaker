# 0028 — The overlooked nine

Date: 2026-08-27
Lane: **Express (same-day, reversible).** Research-data addition to a committed JSON
file, run through the existing story-0019 pipeline unchanged. No new code, no schema
change, no new mirror source.

Owner asked directly, mid-session, for a "100 most recognizable CC0 paintings" research
pass (an Artifact, built and delivered outside `specs/`) and then to "add this to our
local and prod." What actually ships is narrower than the ask — see Deviations in
`plan.md` for why, and the R4 note below for why that narrowing did not need a
`decisions/` entry.

## Who

- **Maya** — persona 1, CORE. Same driver as 0019: she looks for a name she already
  knows.
- **Amara** — persona 3, guard rail. Same bar as 0019: a fill must not regress the range
  bars 0013 fought for. It doesn't — see success signal 2.

## Problem

The owner's research artifact (this session, not committed to the repo — a Claude
Artifact) surveyed ~100 lay-recognizable paintings across seven sources: this app's own
four CC0 mirrors (Met, AIC, Cleveland, Minneapolis) plus three the app does not use
(National Gallery of Art DC, Getty, Rijksmuseum, Smithsonian) plus Wikimedia-Commons
scans of museums that don't grant CC0 at all (Louvre, MoMA, Prado, Orsay…).

Cross-checked against what this codebase can actually ingest:

- **Wikimedia/Europeana is a banned ingest source** (`specs/0013-a-deeper-pool/story.md`
  "Considered and rejected" — mixed per-record licences, undisciplined). ~22 of the
  artifact's 100 rows only exist here. Not usable at all.
- **NGA, Getty, Rijksmuseum, Smithsonian are not mirrored sources.** `lib/pool/sources.rb`
  reads exactly four: Met, AIC, CMA, MIA (`decisions/0016`, `specs/0013`). Adding a fifth
  live museum API is a real stack decision (new fetcher, new rate-limit handling, new
  region/rights mapping) — out of scope for a same-day story and not asked for
  explicitly.
- **What's left, once both of those are subtracted, is 54 artist names drawn from works
  the app's own four mirrors could plausibly hold** (the Met/AIC/CMA-sourced rows of the
  artifact). Diffed by hand against the committed
  `user-research/data/0007-recognizable-names.json` (200 names, built by story 0019's own
  Wikidata + pageview pipeline): **41 of 54 are already on that list.** The gap is nine
  names, all pre-1931 deaths (so `public_domain` under the same rule `build_list.py`
  already applies): Gilbert Stuart, George Catlin, John Singleton Copley, Georges de La
  Tour, George Bellows, Rembrandt Peale, Thomas Moran, Jan Steen, Emanuel Leutze.

This is the actual, addressable problem: nine real, verifiable gaps in the recognizable-
name research list, not "100 paintings."

## Story

As **Maya**, when I look for a painter whose name I already know, I want the app's own
coverage measurement to see that name if the app's own museum mirrors hold their work —
so a real gap gets found, and a name that was never actually missing doesn't get
reported as one.

## Intake

- **Problem:** above — nine names absent from `0007-recognizable-names.json`, verifiable
  against the same Wikidata + Wikipedia-pageview instruments the list's own build script
  uses.
- **Evidence:** this session's museum-research artifact (five parallel research passes,
  cross-checked against live museum API/object-page license statements); diffed against
  the committed 0007 list; each of the nine re-verified today directly against Wikidata
  (SPARQL, same endpoint `user-research/scripts/0007/sparql.py` uses) and the Wikipedia
  pageviews API (same endpoint `pageviews.py` uses) — not hand-typed.
- **Success signal (prediction, falsifiable and time-bound):**
  1. **Today:** `bin/rails pool:coverage` reports 209 names (200 + 9), reachable coverage
     recomputed, and `test/lib/pool_quota_test.rb`'s existing ≥90% assertion still
     passes — the forcing function already exists (story 0019), this story adds rows to
     what it measures rather than writing a new one (R1).
  2. **Today:** re-running `bin/rails pool:curate` against the same cached mirrors
     (`tmp/pool/*.json`, 2026-08-13/18, not re-fetched — same choice 0019 made) produces
     either an unchanged `db/seeds/paintings.json` (all nine already adequately
     represented) or a bars-green manifest with a few names topped up toward `DEPTH = 3`.
     **Falsified if** `Unmeetable` — logged, not silently retried.
  3. **Before this ships as done:** prod's live pool is queried directly (read-only,
     `kamal app exec`) for at least one work by each of the nine names, so "in prod" is a
     receipt, not an inference from a manifest diff (R7).
- **In baseline?** Recognizable-name coverage is 0019's mechanism, already shipped and
  load-bearing (`pool_quota_test.rb`). This story feeds it nine more real rows.
- **R7 note:** moves 0 of 5 `BET.md` thresholds. Four days from the Aug 31 kill review;
  done same-session specifically because it's small enough not to cost any of them.

## Non-goals

- **The other ~91 rows of the research artifact.** Not committed anywhere in this repo —
  the artifact itself is the deliverable for those; see Deviations.
- **A fifth museum mirror** (NGA/Getty/Rijksmuseum/Smithsonian). Real option, not decided
  here — would need its own `decisions/` entry and a `lib/pool/sources.rb` fetcher, same
  shape as the existing four.
- **Reopening `pool:mirror`.** The cached 2026-08-13/18 mirrors are reused, same choice
  0019 made for the same reason (network cost, determinism). Named here because Emanuel
  Leutze's absence (see plan.md) is partly a symptom of mirror staleness, not just rights.
