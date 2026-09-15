# 0026 — The three terms

Date: 2026-09-15
Spec: none — this names what `BET.md` left unnamed. The bet's ASO threshold reads
"3 keywords ranked top 100" and never says which keywords, which is a kill review
argued over after the fact. Fixed here, before the app is released, so the Sep 30
review counts against a list it did not get to choose.

Position: the three counted terms are **`daily art`**, **`one painting a day`** and
**`daily art history`**, US storefront, measured by `script/aso-rank` (iTunes Search
API, position of `com.dhaneshnm.tondo` in the first 200 results). A term counts when
Tondo appears at position ≤ 100. Three watch terms (`art history`, `daily painting`,
`daily masterpiece`) print alongside for context and never count.

Why these three, not the plan's:

- `specs/0016-the-listing/plan.md` predicted the ranked terms would be `history`,
  `museum` and `daily art`. Single words `history` and `museum` are generic shelves
  where a zero-rating app has no realistic path to the top 100 by Sep 30, and both
  were chosen to test Apple's phrase-building across name/subtitle/keyword fields —
  which `daily art history` tests directly (`daily` + `art` from the name, `history`
  from the keyword field) without spending a slot on a term the bet cannot win.
- `daily art` is Maya's literal query (`specs/0016` §Who). Non-negotiable.
- `one painting a day` is the subtitle verbatim. The shelf is the shallowest of the
  candidates probed (156 results) and the top of it is paint-by-number apps, not
  daily-art incumbents — the most winnable of the three.
- Probed and rejected: `painting a day` (paint-by-number shelf, no art-history
  intent), `art a day`, `museum art`, `daily masterpiece` (kept as a watch term —
  one competitor owns the phrase in its name).

Baseline, run 2026-09-15 before release: **0 of 3**, Tondo absent from all six
shelves (153–184 results each). Expected — the version is approved, not released.

Instrument caveat, so it is not rediscovered at the review: the Search API is a proxy
for App Store search ranking, not the ranking itself. It is repeatable, loggable and
free; on-device search is personalised and produces no receipt. If the two visibly
disagree on a term, the script's number is the one the review reads, and the
disagreement gets noted here rather than used to pick the friendlier figure.

## Prediction (falsifiable, time-bound)

By **Sep 30, 2026**, `script/aso-rank` shows `one painting a day` ≤ 100 within seven
days of release, and `daily art` ≤ 100 by the review — with `daily art history` the
one most likely to miss. Falsified if `one painting a day` is still absent from the
top 100 a week after release: that would mean subtitle text alone does not rank a
zero-rating app on its own exact phrase, and the "rating count is the barrier"
finding (`user-research/0005` §3.1) is the whole story, not half of it.
