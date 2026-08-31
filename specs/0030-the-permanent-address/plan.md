# 0030 — Implementation plan
Story: `specs/0030-the-permanent-address/story.md`.
Status: Reviewed (/plan-eng-review, 2026-08-31 — 3 findings folded, all auto-selected
under the standing review delegation; see Eng review section below)

## Approach

One new walled page, `GET /paintings/:id` → `PaintingsController#show`, giving every
painting a permanent address independent of whether it was ever a Daily Pick. Reuses
the `paintings/_painting` partial verbatim — the same plate, zoom trigger, keep control,
title, artist line, museum description and credit line already shipped on `/feed` and
`/artists/:slug` — so there is no new content or copy to write, only a new place to
land on it.

`days/_row.html.erb`'s collection/archive row is the only caller that changes: today it
renders an unlinked `<div>` when a favorite has no published pick. It now links to
`painting_path(painting)` instead. A picked work keeps going to `day_path` — richer
(hand-written blurb, dated context) and unaffected by this story; the new page is the
fallback for what `day_path` cannot address, not a replacement for it.

Models touched: none (no migration — `Painting.id` is already the address). Routes:
one new line. Controllers: `PaintingsController` gains `#show`; `ErrorsController`
gains one `MESSAGES` entry, mirroring the `ArtistsController::NotFound` pattern exactly
— without it, a bad `:id` would 404 with "There was no artwork on that day," which is
wrong and would read as a shipped bug the moment anyone hits a stale link.

### Decisions

| Decision | Choice | Why |
|---|---|---|
| URL shape | `GET /paintings/:id` (numeric, the PK) | No slug exists on `Painting`; inventing one is 0018's whole second unit of work, not needed to fix this bug (story's Out of scope) |
| Route name | `as: :painting` → `painting_path` | Free — `favorite_path` already addresses `/collection/:painting_id` under a different name, no collision |
| Universal or fallback-only? | **Route is universal** (works for any painting, picked or not) — literally what was asked. **Row linking is fallback-only**: `days/_row.html.erb` still prefers `day_path` when a pick exists | A picked work's day page carries the hand-written blurb and dated context; nothing about this story should make that page worse-served |
| Content | Reuse `paintings/_painting` partial, unmodified | Already shows everything a single work needs: plate+zoom, keep control, title, artist line, `painting.description` (museum text, never AI-written — CLAUDE.md), credit line |
| Wall + caching | `require_reader` (default, no skip) + `private_revalidate`, automatic `Rack::ETag` (no manual `stale?`) | Same contract as `/artists/:slug` — reached from a walled surface (the collection), no reason to be more public than what links to it |
| 404 message | New `PaintingsController::NotFound < ActiveRecord::RecordNotFound`, `ErrorsController::MESSAGES` entry | Bare `RecordNotFound` would answer "There was no artwork on that day" — wrong, and silently wrong (a 404 that still renders, easy to ship unnoticed) |
| Masthead | `label: "Painting"`, `here: nil`, no `aside` | Mirrors the artist page's category-word label above the partial's own `<h2>` title; `here: nil` because this is not a compass surface — reached only from a kept-work tap, never self-linking (same reasoning as `/artists/:slug`) |
| Resting works (no image) | Page still renders — `shared/_plate`'s existing `resting: "This work is resting."` fallback, same string `/feed` already shows | A kept work with no image is still a work you kept; the partial already handles this, nothing new to build |

## Eng review — 2026-08-31, findings folded before implementation

All three auto-selected under the standing review delegation (owner: "go with your
recommendations for all decisions" in review skills); none is a direction reversal.

- **E1 — route constraint.** The route gains `constraints: { id: /\d+/ }`, matching
  every sibling painting route (`/collection/:painting_id` ×3, `config/routes.rb:141-149`).
  Junk paths (`/paintings/wp-login.php` — live scanners hit this box daily) 404 at
  routing with the generic "That page does not exist.", and `PaintingsController::NotFound`'s
  copy stays reserved for a well-formed id that's gone.
- **E2 — unify the row, don't patch it.** Step 5 rewritten: `days/_row.html.erb`
  collapses to ONE branch — every row is an `<a>`, `href = pick ? day_link_path(pick,
  current) : painting_path(painting)`. The Remove button and its form are DELETED:
  their justifying comment ("an orphan is the one row whose owner has no other way to
  let it go") is false once the row links, and the coda's "To let one go, open it and
  unkeep it" becomes universally true for the first time. Dead CSS goes with it:
  `.days__remove*` (3 blocks), `.days__link--gone`, and the `main.css:1178-1180`
  comment that names Remove as "the one thing that still acts" — stale prose the
  moment this ships. The no-pick anchor carries `aria-label="<title>, <artist>"`
  (the pick branch's label has date/title/artist; a link with no accessible name
  is a regression against it).
- **E3 — "No longer a day" is deleted, slot ships empty.** `days/_row_body.html.erb:11`
  renders "No longer a day" for every nil-pick row — after this story, nil-pick
  overwhelmingly means "never was a day" (kept from `/feed`), and the two cases are
  indistinguishable in data. The date slot renders empty for nil-pick rows. Owner-copy
  hook: if a string is ever wanted there, it's hand-written and must be true for BOTH
  cases (curator-removed day AND never-picked) — flagged, not supplied.

Outside voice (Codex, high effort, read the repo): 8 findings — 3 independently
re-derived E1/E2/E3 (cross-model agreement, strong signal), 4 new ones folded below,
1 tension resolved on the record:

- **C1 — the 404 would have been a 500.** `ActionDispatch::ExceptionWrapper.rescue_responses`
  keys on the EXACT class name — `config/application.rb:63-72`'s own comment says so, and
  registers `"ArtistsController::NotFound"` explicitly. `PaintingsController::NotFound`
  needs the same `rescue_responses.merge!` line or every miss 500s. And the controller
  must be `Painting.find_by(id: params[:id]) or raise NotFound` — letting a bare
  `RecordNotFound` bubble answers with "There was no artwork on that day."
- **C2 — the page needs an `<h1>`.** The masthead label is a `<p>`; `_painting` emits
  the title as `<h2>`; `artists/show` sets the precedent of a real page heading.
  Mechanism: the partial's title tag becomes `local_assigns.fetch(:heading_tag, :h2)`
  (mirrors the `show_artist:` local idiom); only the new page passes `:h1`. Every
  existing caller unchanged.
- **C4 — native navigation, decided explicitly.** No `ios/Tondo/path-configuration.json`
  rule: default push presentation from a `/collection` tap, the same treatment
  `/artists/:slug` and `/days/:date` get (neither has a rule). Not an omission — a call.
- **Tension, resolved: numeric PK stays.** Codex: "if rows are ever reseeded/reimported,
  `/paintings/:id` is not permanent." Checked against the real mechanism: `db:seed`
  UPSERTS by `(source, source_id)` — ids survive every normal reseed; only a from-scratch
  rebuild breaks them, and that also destroys favorites and device rows. A natural-key
  route (`/paintings/cma-163797`, the admin scheduling idiom) is more durable but buys
  nothing on a walled per-reader page with no sharing surface. If this page ever goes
  public/shareable, revisit the key — that's the recorded boundary.

## Steps

1. **Route.** `get "paintings/:id" => "paintings#show", as: :painting,
   constraints: { id: /\d+/ }` (E1) in `config/routes.rb`, near the existing
   `feed`/`feed_index` lines.
2. **Controller.** `PaintingsController#show`:
   - `class NotFound < ActiveRecord::RecordNotFound; end` (mirrors
     `ArtistsController::NotFound`).
   - `@painting = Painting.find_by(id: params[:id]) or raise NotFound` (C1 — a bare
     `RecordNotFound` bubbling up answers with the day-archive 404 message).
   - `private_revalidate`.
   - `@kept_ids = kept_ids_for([@painting])`.
3. **Error plumbing (two registrations, not one — C1).**
   - `ErrorsController::MESSAGES` gains `PaintingsController::NotFound => "No such
     work here."` (exact copy is the owner's call at implement time — placeholder).
   - `config/application.rb` gains `"PaintingsController::NotFound" => :not_found` in
     the existing `rescue_responses.merge!` block — the wrapper keys on the exact
     class name (that block's own comment), so without this line every miss is a 500.
4. **View.** `app/views/paintings/show.html.erb`:
   ```erb
   <% content_for :title, "#{@painting.title} — Tondo" %>
   <% content_for :description, "#{@painting.title}, #{@painting.artist_display}, on Tondo." %>
   <%= render "shared/masthead", label: "Painting", here: nil %>
   <main class="page" data-controller="artwork">
     <%= render partial: "paintings/painting", collection: [ @painting ],
           locals: { kept_ids: @kept_ids, heading_tag: :h1 } %>
     <%= render "shared/zoom" %>
   </main>
   ```
   `heading_tag:` is C2 — the masthead label is a `<p>` and the partial's title is an
   `<h2>`, so without this the page has no primary heading. The partial's title line
   becomes `content_tag local_assigns.fetch(:heading_tag, :h2), ...` — every existing
   caller (`/feed`, `/artists/:slug`) renders exactly as before.
   (`data-controller="artwork"` on `<main>` matches `/artists/:slug` — the zoom JS
   needs it at that scope; confirm against `artwork_controller.js` at implement time
   rather than assuming the artist page's wrapper is the only place it's declared.)
   **Native shell (C4):** no `path-configuration.json` rule — default push
   presentation, same as `/artists/:slug` and `/days/:date`.
5. **The row unification (E2, supersedes the original patch-the-else-branch step).**
   `days/_row.html.erb` collapses to one branch: every row is an `<a class="days__link">`,
   `href = pick ? day_link_path(pick, current) : painting_path(painting)`; aria-label
   keeps date/title/artist when a pick exists, title/artist when not. Remove button,
   its form, `.days__remove*` and `.days__link--gone` CSS, and the stale main.css
   comment all deleted. `days/_row_body.html.erb`'s nil-pick date slot renders empty —
   "No longer a day" deleted (E3).
6. **Smoke locally.** Keep a `/feed`-only work that has never been a Daily Pick (any
   dev-pool work not in `daily_picks`), open `/collection`, confirm the row is a real
   link opening `/paintings/:id` with that exact work, unkeep from the page, confirm
   the row is gone back on `/collection` — the full path Remove used to shortcut.

## Tests

- `test/integration/paintings_test.rb` (new or extended): `GET /paintings/:id` for a
  signed-in reader / registered device renders 200 with that painting's title; signed-
  out (no device, no session) 303s to `/you` like every other walled page; unknown id
  404s with the new message, not the day-archive one; a resting (no-image) painting
  still renders its fallback text rather than raising.
- `test/integration/favorites_test.rb` (or wherever `/collection` is covered today):
  a favorite with no published pick renders a real `<a>` to `painting_path`, not the
  `days__link--gone` div; a favorite WITH a published pick still renders `day_path`
  (regression guard — this story must not touch the picked-work path).
- System test (Capybara): keep a non-picked work from `/feed`, visit `/collection`,
  click the row, land on the painting's own page, image visible, Keep control still
  reflects kept state.

Added by eng review (coverage gaps, 5):
- Non-numeric id (`/paintings/abc`) 404s at routing — asserts E1's constraint holds.
- A painting WITH a published pick also answers 200 on `/paintings/:id` — the route is
  universal; nothing else asserts that half.
- The new page's `Cache-Control` is private, never `public` — the walled-page contract,
  currently only asserted from the public side (`public_cache_headers_test`).
- **CRITICAL (regression rule):** system test — orphan row → open painting page →
  unkeep → back on `/collection` the row is gone. E2 deletes a working control
  (Remove); this proves the relocated affordance end-to-end or E2 ships a regression.
- Row assertions updated for E2/E3: no `days__remove` form anywhere in `/collection`,
  no "No longer a day" text, every row's anchor carries an aria-label.

## Deviations (added during build)

- (none yet)

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found (absorbed) | 8 findings: 3 re-derived E1/E2/E3, 4 folded (C1/C2/C4 + PK boundary), 1 tension resolved |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 7 issues, 0 critical gaps — all folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | skipped: UI-light (reuses shipped partials wholesale), noted per build flow step 3 |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CODEX:** outside voice re-derived 3 of 3 pre-fold findings independently and added the
  rescue_responses 500 trap, the missing h1, and the explicit native-nav call — all folded.
- **CROSS-MODEL:** high overlap (route constraint, Remove-button special case, false
  "No longer a day" copy found by both models independently). One tension — PK vs
  natural-key URL — resolved on the record: PK stays, boundary documented.
- **VERDICT:** ENG CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
