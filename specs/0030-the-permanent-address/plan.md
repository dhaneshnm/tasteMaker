# 0030 — Implementation plan
Story: `specs/0030-the-permanent-address/story.md`.
Status: Draft

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

## Steps

1. **Route.** `get "paintings/:id" => "paintings#show", as: :painting` in
   `config/routes.rb`, near the existing `feed`/`feed_index` lines.
2. **Controller.** `PaintingsController#show`:
   - `class NotFound < ActiveRecord::RecordNotFound; end` (mirrors
     `ArtistsController::NotFound`).
   - `@painting = Painting.find(params[:id])`, rescued into `NotFound` — or let
     `ActiveRecord::RecordNotFound` bubble and rescue-map it explicitly; match
     whichever idiom `ArtistsController` actually uses once re-read at implement time.
   - `private_revalidate`.
   - `@kept_ids = kept_ids_for([@painting])`.
3. **Error message.** `ErrorsController::MESSAGES` gains
   `PaintingsController::NotFound => "No such work here."` (exact copy is the owner's
   call at implement time — placeholder here, not shipped as final without a look).
4. **View.** `app/views/paintings/show.html.erb`:
   ```erb
   <% content_for :title, "#{@painting.title} — Tondo" %>
   <% content_for :description, "#{@painting.title}, #{@painting.artist_display}, on Tondo." %>
   <%= render "shared/masthead", label: "Painting", here: nil %>
   <main class="page" data-controller="artwork">
     <%= render partial: "paintings/painting", collection: [ @painting ],
           locals: { kept_ids: @kept_ids } %>
     <%= render "shared/zoom" %>
   </main>
   ```
   (`data-controller="artwork"` on `<main>` matches `/artists/:slug` — the zoom JS
   needs it at that scope; confirm against `artwork_controller.js` at implement time
   rather than assuming the artist page's wrapper is the only place it's declared.)
5. **The row fix.** `days/_row.html.erb`'s `else` branch (no `pick`): wrap the existing
   `days/row_body` render in `<a href="<%= painting_path(painting) %>">` instead of a
   bare `<div>`, keeping the sibling "Remove" `button_to` exactly as-is (the existing
   comment about not nesting a button inside an anchor still applies — Remove stays
   outside the new `<a>`, same structure the `pick`-present branch already uses).
6. **Smoke locally.** Keep a `/feed`-only work that has never been a Daily Pick (any
   dev-pool work not in `daily_picks`), open `/collection`, confirm the row is now a
   real link, confirm it opens `/paintings/:id` showing that exact work, confirm Remove
   still works from the new unlinked-no-more row *before* the fix and from the linked
   row after.

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

## Deviations (added during build)

- (none yet — Draft)
