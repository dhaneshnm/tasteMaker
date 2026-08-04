# 0006 — The collection you keep
Date: 2026-08-04
Lane: Full (core, target ≤ 2 days)
Status: Draft

## Who
**Jordan** — Collector / Wishlist-keeper, persona 2 (`specs/personas.md`). 26, barista and
part-time community-college student in Portland. Money is tight; the favorites list is the
art collection they can afford right now — a wishlist of prints for the apartment they'll
have "when I have a better job." Three years of slow curating on a cracked-screen iPhone.

Secondary: **Ruth**, persona 6, the lifecycle state Jordan becomes if we ever put this
list behind a paywall. She is not a target — she is the failure mode.

## Problem
Today a reader who loves the Wednesday artwork has exactly one way to keep it: remember
the date. `/days` will show it again, buried among every other day, in publication order,
with no mark on it. The product asks for a daily habit and then gives the reader nothing
to accumulate — the archive is *our* record of what we published, not *their* record of
what they liked.

Persona 2 is the loudest pain in the whole review corpus (~6 of 31), and it is not "I want
a favorites button." It is what happens **after** three years of pressing it:

> "All of my favorite pieces… collected over multiple years are out of reach… locked
> behind a paywall I cannot afford."
> "Half the reason I used it was to have a catalogue of great art."
> "The favorites feature should be free to all users."

The leader built the collection, taught people to depend on it, then charged rent on it.
That is the single most reputation-destroying move in this category's review history, and
it is the reason we get to enter it at all.

## Story
As Jordan, I want to keep the works that stop me and find them again in one place, so that
the app becomes a collection I am building rather than a stream I am watching.

## Intake
- Evidence: **Proven baseline item 4** (`CLAUDE.md`). Persona 2 is ~6 of 31 reviews
  analysed and is the only persona whose *entire* behaviour is this feature — the quotes
  above are about losing the list, which means the list was the product. Persona 6 (~7
  reviews) is the same feature seen from after the betrayal. `specs/personas.md` already
  writes the contract this story has to honour: **"Favorites free forever, never
  data-hostaged."** Baseline item 5 (free at launch) is the same promise from the other
  side.
- Success signal (prediction), hand-checkable the day it lands, no analytics required:
  1. Keeping a work is **one tap from the day page**, does not navigate, and does not
     interrupt — no modal, no toast, no sign-up.
  2. The kept work is at `/collection`, newest first, and survives a browser restart.
  3. `curl -sI /` returns the **same ETag and no `Set-Cookie`** whether the caller holds a
     collection or not — the front door stays a public, shared-cacheable page.
  4. Nothing about the daily ritual moves: same layout, same load, same calm.
- Honest caveat, stated up front: this is **device-local**. Delete the app and the
  collection is gone. On ship day the collection can hold at most as many works as there
  are published days — one or two. Its value compounds exactly like the archive's, and on
  day one it is nearly empty. The reasoning and the trigger for revisiting live in
  `plan.md` and in the `decisions/` entry this story requires.
- Measurement gap, named rather than papered over: no analytics are wired yet (session
  gate 6), so "how many people keep anything" is not answerable at the Aug 31 kill review.
  This story is not one of BET.md's numeric thresholds and must not be argued as progress
  under R7 — shipped code is an input metric.
- In baseline? Yes — Proven item 4.

## Acceptance
- A reader can keep the artwork of the day, and any past day, from that day's own page.
  One tap. The page does not navigate, reload, or scroll.
- Keeping again removes it. The control states which state it is in, not just what the tap
  will do.
- `/collection` lists kept works, most recently kept first, each opening the day it ran on.
- The collection has **two doors**: `Your collection →` in the archive's coda, always, for
  everyone; and `7 kept →` on a day page once there is something to count. The archive door
  is countless on purpose so it stays byte-identical for every visitor and can live on a
  publicly cached page (design review, D1).
- The collection page says, once, and quietly, that kept works live on this device. The
  limit is stated before it is hit, not after (design review, D4).
- A curator previewing a queued day sees **no** keep control — the preview shows the
  reader's page (design review, D2).
- Kept state survives quitting and reopening the browser or the app shell.
- **No account, no email, no sign-up, no interstitial.** Nothing is asked of the reader
  before or after keeping something.
- **Free. Permanently.** No count limit, no gate, no "upgrade to keep more".
- The front door, `/days` and `/days/:date` stay publicly cacheable and byte-identical for
  every visitor. One reader's collection is never visible in another reader's response.
- A work whose day was removed by the curator stays in the collection and can still be
  removed by its owner — an editorial action never deletes something a reader kept.
- The control is a real button with a ≥44px touch target (ISSUE-002, commit 866bbc2), and
  pressing it with a keyboard leaves focus on the button rather than dumping the reader at
  the top of the document (design review, D3).
- Nothing floats over the artwork (`DESIGN.md` rule 5), nothing new is added to the
  masthead, and the kept state introduces **no new glyph** — `✦` stays the product's one
  ornament (design review, D7).

## Out of scope
- **Accounts, email, cross-device sync.** Deferred with a written reason and a trigger in
  `plan.md`; the identity decision goes in `decisions/` (R4). Building auth now costs the
  Action Mailer stack that `config/application.rb` deliberately leaves commented out, a
  signup wall in front of the calmest app in the category, and an App Store privacy label
  that says we collect contact information — all before the Aug 14 store deadline, with
  the iOS shell and push still unbuilt.
- **Export / backup of the collection.** Real, and the honest answer to the device-local
  caveat. Not yet: nobody has a collection worth exporting on day one.
- **A keep control on `/feed`.** `/feed` browses 110 museum works with no relation to any
  day; a save control there turns it into a wishlist builder, which is persona 4/5
  territory and explicitly not baseline. Accepted cost, named at design review (D9): the
  day page's own coda says "Wander the full gallery →", so the product invites you into the
  one room where this feature does not work. **Reopens at the Phase 3 gate, or when a real
  user asks for it in one of BET.md's five conversations** — not on a hunch mid-build.
- **Keep controls on `/days` rows.** Thirty per-visitor fragments on a public list, to save
  one tap. The row is already one link; a second interactive element inside it is an
  accessibility defect.
- **Per-row remove on the collection page** — same nested-interactive reason; the toggle on
  the day page is the remove. Trigger written into `plan.md`.
- Folders, tags, notes on kept works, sorting, filtering, or search within the collection.
- Sharing a collection, or any public URL for one.
- A kept count in the masthead — per-visitor state in a public, cached header.
- Push notifications about kept works (baseline item 2, its own story).
- Premium, patronage, or any billing surface. Parked in `CLAUDE.md`, and this is the exact
  feature that must never be near it.
