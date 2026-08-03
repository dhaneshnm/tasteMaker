# 0001 — Artwork of the Day
Date: 2026-08-03
Lane: Full (core, target ≤ 2 days)
Status: Built 2026-08-03 — code complete and merged, awaiting deploy

## Who
**Maya** — Daily Ritual Learner, persona 1 (`specs/personas.md`). 33, pediatric nurse in
Columbus. Art-curious, not expert. Opens once a day with her morning tea, has 1–3 minutes,
wants to feel a little more cultured, then get on with her shift.
Secondary actor: the curator (Dhanesh), who picks the works and writes every blurb.

## Problem
Maya wants a small daily dose of art with a human voice — "my daily dash of culture,"
"keeps me regularly dosed" — without ads, upsells, or an endless feed that turns her
ritual into a scroll session. The category leader serves her but buries the moment under
monetization noise. Our current app has no "today" at all — only infinite scroll.

## Story
As Maya, I want to open the app and immediately see today's single artwork with a short
hand-written note on why it matters, so that I get my art moment in under three minutes
and come back tomorrow.

## Intake
- Evidence: largest persona cluster (~8 negative + 4 positive reviews); "one artwork per
  day + hand-written blurb" is baseline item 1, validated across 17-app teardown.
- Success signal (prediction): once live, the curator can publish a day (pick artwork +
  paste blurb + set date) in under 5 minutes; a visitor hitting the root URL sees today's
  artwork and blurb with zero interactions needed. Checkable day one.
- In baseline? Yes — Proven item 1.

## Acceptance
- Root URL shows today's artwork: image, title, artist, year, and the curator's blurb.
- Blurb is hand-written (typed/pasted by curator; no generated text anywhere in the path).
- Artwork and the blurb's opening share the initial viewport (Better bar 2); the full
  blurb reads in ≤ 2 scrolls; zoom is one tap away while reading. (Reworded at eng
  review — "never hides" was unimplementable without sticky art; Option A layout stands.)
- "Today" is computed correctly for the visitor-relevant timezone rule the plan defines
  (Better bar 5) — no tomorrow-leak, no blank days.
- A day with nothing published shows the most recent published day (graceful, no error),
  dated honestly with the pick's own date.
- Masthead names the moment: wordmark, "Artwork of the Day", date.
- Artwork is tap-to-zoomable full screen (Better bar 7), keyboard-accessible.
- Curator can queue future days: artwork + blurb + publish date.
- Existing infinite-scroll feed remains reachable but is no longer the root (decision 0002:
  frozen, untouched).

## Out of scope
- Push notifications (feature #2, own story — needs shell + APNs).
- Archive/calendar UI (feature #3). Favorites (feature #4).
- Any change to the feed beyond moving it off root.
- New artwork sources or museum-API ingestion — the 110 seeded MIA works are the pool for
  now; API pipeline gets its own story when the pool runs low.
- Widget, accounts, premium.
