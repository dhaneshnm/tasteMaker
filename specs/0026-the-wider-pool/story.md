# 0026 — The wider pool

Date: 2026-08-20
Lane: **Full (≤ 2-day core, plus curation-audit time that is operator work, not
code).** TARGET constant, one curator stage, pinning, seeds + plate cache, deploy.
Status: **Draft — third of the decisions/0016 sequence**, queued behind 0024 and 0025
(R5). **Blocked on decisions/0016 being committed** (R2/R4 — it is, same day) and on
both findability stories shipping first (Rule 2: expansion before findability adds
works nobody can reach).

Promoted from `IDEAS.md` Inbox ("Theme-gap re-curation", captured 2026-08-20) —
**with the mechanism inverted on promotion by owner decision**: the Inbox entry
proposed swap-within-2,000; decisions/0016 records the owner's call to expand
additively to 3,000 and keep swaps as the fallback. The entry's evidence carries
over; its mechanism does not.

## Who

- **Amara** — persona 3, driver. The facets 0024/0025 light are only as good as
  their stock: Persian miniature sits at ~19 works, thangka ~24, vanitas 0,
  Madhubani 0 — while the mirrors hold 760 / 473 / 6 / 9 qualifying candidates
  outside the pool (`user-research/0008` §3.7).
- **Maya** — persona 1. "Paintings of flowers" demand meets 15 still lifes. The daily
  pick's pool deepens too — 0023's spacing ladder gets more room before tier
  relaxation.
- **Jordan** — persona 2, favorites contract, the hard guard rail this story adds
  code for: every existing work is **pinned**. Nothing a reader favorited or a day
  published can vanish in a re-curation.
- **The curator** — more museum-text works to write ahead of; blurb debt is per-day
  (unchanged by pool size), but the 0004/0015 museum-text banners will show more
  museum-text share. Named, not hidden.
- Not in this story: Tomás directly, Priya/Zoe.

## Problem

**The pool's supply doesn't match measured demand, and at 2,000 there is no room to
fix it without breaking something already promised.** 0008 measured both sides:
demand concentrated in traditions and subjects the pool holds thinly (still life 15,
marine 1, mythological 4, Persian ~19, thangka ~24, ukiyo-e ~18-as-Edo, Madhubani 0)
and mirror stock sitting outside the pool for every one of them (338 / 56 / 71 /
760 / 473 / 16-strict / 9, Met excluded so all floors). The alternative —
swap-within-2,000 — spends works that published days and favorites already
reference, or spends range the bars protect. decisions/0016 chose: **widen to 3,000
additively, bars held as shares, swaps only as fallback.**

## Story

As **Amara**, I want the themes the app can now name to hold enough works to be
worth visiting, so a facet tap lands in a room, not a closet.

## Intake

- **Problem:** above.
- **Evidence:** `user-research/0008` §3.1–3.7 (demand ranking, pool mapping, mirror
  stock probe, raw data committed); decisions/0016 (the direction call, with its own
  falsifiable predictions this story executes against).
- **Success signal (prediction, falsifiable and time-bound):**
  1. **By Aug 28:** committed manifest = 3,000 works; all 2,000 prior works present
     unchanged (pin assertion in `pool_quota_test`); every 0013 bar green at the new
     floors (non-Western ≥ 1,350, text ≥ 2,100, region ≤ 750, ≤ 5/artist);
     `bin/ci` green. **Falsified if** `verify!` raises `Unmeetable` at every viable
     configuration — decisions/0016 prediction 1 dies and the swap fallback executes
     instead, on the record.
  2. **By Aug 28:** each targeted theme clears its named floor from expansion alone —
     Persian miniature ≥ 25, thangka ≥ 15, still life/flowers ≥ 40 total, marine
     ≥ 12, mythological ≥ 15, ukiyo-e ≥ 5 strict (of 16 candidates), Madhubani ≥ 5
     (of 9, rights-verified), vanitas+trompe-l'œil ≥ 5, icons ≥ 5, cityscape ≥ 10.
     **Falsified per-theme** if stock fails adjudication (bad plates, wrong
     attribution) — shortfall logged in the pool report, not papered over.
  3. **Facet truth on `/feed`:** every value the UI offers still clears
     `MIN_FACET_WORKS` — by the existing construction; the assertion is that the
     *new* values (Flowers, Persian & Islamic Painting, Tibetan & Nepalese Painting,
     Vanitas…) light for real.
- **In baseline?** The pool pipeline is Proven baseline; the *size* is a settled 0013
  bar, reopened deliberately and only via decisions/0016 (R4 satisfied). Aggregation
  trap distinction stated there: theme-directed curation at 3K, not bulk.
- **R7 note:** moves **0 of 5** `BET.md` thresholds. Lands ~3 days before kill
  review; decisions/0016 names that cost. If the review kills the app, this story's
  artifacts are the reusable part (curated CC0 manifest + research).

## Non-goals

- **Swaps** — fallback only, triggered by falsification 1 or 2, executed under this
  spec with a Deviations note, not silently.
- **Movement-targeted acquisition** — Rule 3: no buying "Baroque" by date arithmetic.
  Movement stock arrives when the reconciliation story exists to verify it by P135.
- **TARGET beyond 3,000** — decisions/0016 tripwire 3 gates any such talk on
  observed facet usage.
- **New editorial obligation** — museum-text fallback (0005) covers new works;
  BANNED line unmoved.
- **Met plate resolution rework** — existing `resolve_met_image` selection-time
  behavior is reused as-is; if Met stock proves unphotographed, the fill takes from
  the other three (probe already counted without Met).
