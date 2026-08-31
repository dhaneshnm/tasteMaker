# 0030 — The permanent address
Date: 2026-08-31
Lane: Express (same-day, reversible). No migration, no data change — a new route,
one controller action, one view, reusing partials already shipped.
Status: Draft

## Who

- **Jordan** — persona 2, Collector/Wishlist-keeper (`specs/personas.md:33`), loudest
  pain in the review corpus. "Favorites are the product: a personal catalogue built
  over years." The collection IS the thing they came back for — a row in it that goes
  nowhere is the DailyArt paywall complaint's quieter sibling: the catalogue looks kept,
  but it isn't reachable.
- **Maya** — persona 1, CORE. Keeps things off `/feed` in passing, the same casual way
  she keeps things off the front door. She has no mental model that distinguishes "today's
  official pick" from "something I liked scrolling" — both are just kept.

## Problem

**A kept work only opens if it was, at some point, a published Daily Pick.**
`FavoritesController#index` joins each favorite to `DailyPick.published` by
`painting_id` (`app/controllers/favorites_controller.rb:78-87`); `days/_row.html.erb`
renders the row as a bare, unlinked `<div>` plus a "Remove" button whenever that join
comes back nil (lines 24-38, "the day the curator removed" is the comment's framing,
but the join has no way to tell that apart from "never picked at all").

Since story 0020 shipped keeping *from* `/feed` and `/artists/:slug` — the pool, not
just the daily picks — most of what the collection can now hold has never been and may
never be a Daily Pick. Every one of those rows is a dead end today: kept, visible,
un-openable, with nothing to do but remove it.

**Found 2026-08-31**, reported live: a work kept from `/feed` (tappable there — the
Story 0002 zoom overlay) sat unlinked in `/collection`, reachable by no other URL —
confirmed by reading the code, not inferred: no route in `config/routes.rb` gives a
painting a page independent of a date. `/feed`'s tap opens an in-page zoom, not a URL,
so a work that is only ever *kept* — never picked, never zoomed again after that
session — has genuinely no address in the app.

## Story

As **Jordan**, I want every work I keep to open to its own page, so my collection is a
catalogue I can actually revisit — not a list I can only delete from.

## Intake

- **Evidence:** Live bug report, 2026-08-31 — a kept, non-picked work stuck unlinked in
  `/collection`. Root cause confirmed in code (cited above), not data corruption or an
  auth-provider defect — `grep` across `app/` found zero logic branching on OAuth
  provider; the sole determinant is `DailyPick.published` coverage for that
  `painting_id`. Structural since story 0020 (keep-from-`/feed`) shipped without a
  corresponding "open what I kept" path — this story closes that gap.
- **Success signal (prediction, falsifiable and time-bound):** Within one week of ship,
  zero rows in `/collection` render as the unlinked `days__link--gone` state for any
  *reachable* painting (soft-deleted/pulled-from-pool works are the one legitimate
  exception, out of scope below). Checkable directly: keep a `/feed`-only work that has
  never been a Daily Pick, open `/collection`, tap it, land on `/paintings/:id` showing
  that exact work. **Falsified if** the tap still does nothing, or if it lands on the
  wrong work.
- **In baseline?** Yes — baseline item 4, Favorites/personal collection. This is a
  completeness fix to an existing baseline item, not new scope: the collection promise
  ("kept, yours, free forever" — Jordan's persona note) already implies "and you can
  look at it again."

## Out of scope

- Changing `/feed`'s tap-to-zoom UX. It already works (user-confirmed); this story adds
  a second, permanent way to see a work, it doesn't replace the first.
- Linking work titles on `/artists/:slug` to the new page. Real candidate for later,
  free to add once `/paintings/:id` exists, but not needed to close the reported bug —
  naming it here rather than folding it in silently (WIP creep).
- A slug for the URL (`/paintings/:artist-title-slug` or similar). `Painting` has no
  per-work slug today (only `artist_slug`), and inventing one is a second unit of work
  (uniqueness, transliteration, the exact traps 0018 hit) this bug fix doesn't need —
  the numeric `id` is stable and already the primary key `favorite_path` addresses by.
- Retiring or redirecting `/days/:date` for picked works. A picked work keeps its
  dated URL and its hand-written blurb; the new page is the fallback for work that
  never had either, not a replacement for the richer page that already exists.
- Any editorial writing. `CLAUDE.md`'s ban on AI-generated descriptions stands; the new
  page shows `painting.description` (museum text) exactly as `/feed` already does for
  the same works today (`paintings/_painting.html.erb:44`) — no new copy obligation.
