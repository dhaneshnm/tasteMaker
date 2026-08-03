# 0001 — Implementation plan
Status: **Built** (2026-08-03, commit 4221f55 + audit fixes). All 21 tasks done, `bin/ci`
green including system tests. Not deployed — step 10's pre-launch content checklist and a
Kamal setup story stand between this and a live site.

## Data flow
```
                      ┌────────────── curator (basic auth) ──────────────┐
                      │  /admin/daily_picks: form → validate → save      │
                      │  (dup date? no image? → inline error)            │
                      │  member GET :preview → renders daily/show        │
                      ▼                                                  │
  paintings (110) ──▶ daily_picks (painting_id ∪, scheduled_on ∪, blurb) │
                      │                                                  │
                      ▼ DailyPick.current  = latest scheduled_on ≤ Date.current
  visitor ──▶ GET / ──▶ daily#show ── fresh_when(pick) ──▶ 304 | render
                      │                                     (no-cache + ETag)
                      └─ none at all ──▶ empty state ("first artwork arrives soon")
  Fallback timeline:  Aug1✓  Aug2✓  [Aug3 unscheduled → Aug2 shown, dated Aug 2]
```

## Approach
New `DailyPick` model joins a `Painting` to a calendar date and carries the curator's
hand-written blurb (separate from `paintings.description`, which is museum copy). Root
route becomes the today view; the feed moves to `/feed` untouched (decision 0002). A
minimal HTTP-basic-authed admin lets the curator queue future days. No new gems, no
Solid Queue yet — nothing here needs a job; the "publish" event is just `scheduled_on`
arriving.

## Data
`daily_picks`:
- `painting_id` — FK, null: false, unique (a painting is featured at most once —
  kept as a DB constraint through the kill review; revisit trigger: relax via
  migration when the museum-API ingestion story grows the pool, per eng review Eng-7)
- `scheduled_on` — date, null: false, unique (one pick per day)
- `blurb` — text, null: false (hand-written; no generated text on this path)

Model: `belongs_to :painting`; validations mirror the constraints; additionally a
painting failing `display_image?` cannot be scheduled (keeps the broken-image state
nearly unreachable). `DailyPick.current` → pick with latest `scheduled_on <=
Date.current` (fallback for unscheduled days comes free: yesterday's pick stays up,
honestly dated — see masthead).

## "Today" rule (Better bar 5)
**Confirmed at design review:** day rolls at midnight `America/New_York`. NOTE:
`config/application.rb:36` currently has the timezone COMMENTED OUT — setting
`config.time_zone = "America/New_York"` is an explicit implementation step, with a
midnight-boundary model test (pick scheduled tomorrow ET invisible at 23:59, visible
at 00:00). No per-visitor timezone logic. No tomorrow-leak: `current` never selects
`scheduled_on > Date.current`.

## Routes
- `root "daily#show"` (was `paintings#index`)
- `get "feed" => "paintings#index"` — feed reachable, frozen; fix its lazy-frame
  next-page URLs if they assume root
- `namespace :admin { resources :daily_picks, except: :show do member { get :preview } end }`
  — preview is an action ON the authed admin controller (auth inherited; a public
  preview route would leak unpublished picks — eng review Eng-1). It renders the
  `daily/show` template for that pick.

## Today view — design spec (from /plan-design-review 2026-08-03, 11 decisions)

Layout direction: **Option A "Gallery wall"** (approved wireframe:
`~/.gstack/projects/tasteMaker/designs/today-view-20260803/wireframe.html`).

**Hierarchy (top → bottom):** masthead → artwork → title block → blurb → closing beat →
gallery link. What Maya sees first/second/third: art, title, opening lines of the note.

1. **Masthead** — wordmark `TASTEMAKER` + label "Artwork of the Day" + date in small
   caps (0.78rem, letter-spacing .18em). Date is the PICK's `scheduled_on`, never
   `Date.current` — fallback days show their true date, the page never lies.
2. **Theme — "morning room / gallery at night."** Today view gets a scoped linen
   palette on `body.daily` via CSS variables: linen `#f4efe6` bg, warm ink `#2a241c`,
   existing gold accent darkened to meet AA on linen (≥4.5:1 text, 3:1 UI — current
   `#c8a463` is 1.9:1, fails). Keep Fraunces/Newsreader stack. Feed keeps its dark
   theme untouched (decision 0002). The light↔dark transition between rooms is named
   and intentional. The linen screen is paper: no `prefers-color-scheme` dark variant.
3. **Artwork treatment — never crop.** `object-fit: contain; max-height:
   min(55vh, 55dvh); max-width: 100%; margin-inline: auto`. Letterbox field = page
   background. Extreme aspect ratios (<0.5 tall scrolls, >2.5 panoramas) resolve to
   "whole painting visible, smaller." Do NOT reuse feed's `.art img { object-fit:
   cover }`.
4. **Loading (LCP)** — reserved box via the feed's `--ar` aspect-ratio pattern +
   `width`/`height` attrs, `loading: eager`, `decoding: async`,
   `<link rel="preload" as="image">` in head. Letterbox shows slightly deeper linen
   while loading.
5. **Title block** — titles never truncate; when >60 chars, size drops to ~1.35rem
   (from clamp base). Artist + year + medium meta line beneath in muted small sans.
6. **Blurb contract** — never clamped on today view (feed clamps; the ritual doesn't).
   Rendered with `simple_format` (curator's paragraphs preserved). Full-ink serif,
   1.06–1.15rem, line-height 1.65 — visually distinct from museum copy.
7. **Fold budget (Better bar 2, measurable)** — at 375×667 (iPhone SE): masthead +
   artwork + title + ≥2 lines of blurb visible without scrolling. System test asserts
   blurb's bounding rect intersects initial viewport, not just presence in DOM.
8. **Zoom (Better bar 7)** — `zoom` Stimulus controller. Image wrapped in
   `<button aria-label="View <title> full screen">`. Tap → full-bleed overlay
   (`object-fit: contain` on page bg), tap-anywhere or Escape dismisses, `aria-modal`
   + focus trap, body scroll locked, `prefers-reduced-motion` skips the transition.
9. **Closing beat** — ornament divider + italic "See you tomorrow." ABOVE the feed
   link, which reads "Wander the full gallery →". Entering the feed is a chosen
   departure, not the default continuation.
10. **Accessibility** — descriptive alt ("Title — Artist"); blurb linked to image via
    `aria-describedby`; zoom keyboard-reachable; all linen colors AA.
11. **Caching (corrected at eng review — Eng-6)** — `Cache-Control: public, no-cache`
    + ETag via `fresh_when(@pick)`. Every request revalidates; unchanged content is a
    cheap 304; blurb edits and midnight rollover propagate instantly. (Original
    max-age-to-EOD plan was wrong: fresh public caches never revalidate, typo fixes
    would have stalled until midnight.)

### Interaction states
| Feature | Loading | Empty | Error | Success |
|---|---|---|---|---|
| Today artwork | reserved linen box, no CLS | pre-launch: wordmark + "The first artwork arrives soon." | no local image + CDN 404: `onerror` swaps to framed placeholder "This work is resting — read today's note" (`display_image?` trusts the URL, so onerror is the real guard — Codex #10); title+blurb still render | art + blurb co-visible at open |
| Zoom overlay | instant (same asset) | n/a | n/a | full-bleed, Escape/tap closes |
| Admin form | n/a | empty select = all paintings picked, say so | duplicate date / picked painting / no-image: inline messages naming the field | redirect to queue, flash confirms date |

## Screens
1. **Today** (`daily#show`): per design spec above.
2. **Admin queue** (`admin/daily_picks`): `http_basic_authenticate_with`, password in
   Rails credentials. Index = upcoming + past picks. Form: painting select labeled
   "Title — Artist (Year)" — unpicked paintings PLUS the record's own current
   painting on edit (otherwise it vanishes from its own form — Codex #8) — with
   thumbnail of selected painting; date field defaulting to the first unscheduled
   date **≥ today** (never a historical gap — Codex #9); blurb textarea with live
   word count + soft warning outside 60–180 words. Clear inline validation errors.
   Preview link per pick (renders public view). Plain otherwise — curator is the
   only user.

## Steps
1. `config.time_zone = "America/New_York"` (application.rb — currently commented out)
   + midnight-boundary test.
2. Migration + `DailyPick` model (incl. `display_image?` schedulability validation) +
   fixtures + model tests. ASCII timeline comment on the model (fallback behavior).
3. Linen palette scoped to `body.daily` (CSS variables, AA-checked values).
4. `DailyController#show` (eager-load painting + attachment — Eng-3) + view per design
   spec + `fresh_when` no-cache/ETag + integration tests + system tests (fold-budget
   bounding-rect assert; fallback day; empty state; broken-image placeholder).
5. `zoom` Stimulus controller + overlay + system test (open, Escape-dismiss).
6. Route move: root swap, `/feed`, fix feed frame URLs (`_page.html.erb:5` uses
   `root_path` — confirmed break); regression test: feed still paginates.
7. Admin controller + views (labeled select incl. own painting on edit, thumbnail,
   word count, errors, `preview` member action) + auth + tests (401; create/edit;
   duplicate rejection; preview auth + render).
8. Truth pass on chrome (Codex #7): layout `<title>`/meta description reflect daily
   app, PWA manifest name/colors match linen theme, feed keeps its own masthead.
9. Enable `test:system` step in `bin/ci` (currently commented out — fold/zoom
   regressions invisible to CI without it, Codex #5); README root-URL note; CI green.
10. **Pre-launch content checklist (Codex #4, blocks deploy, not merge):** admin
    password in credentials, today's pick published, ≥ 7 future days queued —
    root must never show the empty state to App Review or a first visitor.

## Tests
- Model: unique date, unique painting, blurb presence, no-image schedulability
  rejection, `current` selection incl. no-future-leak.
- Model additionally: midnight ET boundary (tomorrow's pick invisible at 23:59 ET).
- Integration: root renders today's pick; unscheduled day falls back with honest
  date; feed at `/feed` paginates; admin 401 without credentials; admin create;
  duplicate-date error; preview requires auth + renders future pick (Eng-2);
  ETag revalidation (304 on match, fresh after blurb edit).
- System (Capybara): fold budget at 375×667 (blurb rect in viewport); zoom
  open/dismiss; empty-state copy; broken-image placeholder (Eng-2).
- Manual (/qa): word-counter nudge behavior (decision Eng-2 — not worth a JS-driving
  automated test).

## NOT in scope (design decisions considered, deferred with rationale)
- Dark variant of the linen screen — linen is paper; revisit only on user complaint.
- Motion/entrance animations — calm > choreography for a ritual screen; zoom
  transition is the only motion.
- Per-visitor timezones — one ET clock; revisit only if reviews complain.
- Widget, archive UI, favorites — own stories (features #2–4).

## What already exists (reuse, don't reinvent)
- `--ar` aspect-ratio reserved-box pattern + width/height attrs (`_painting.html.erb`).
- Fraunces/Newsreader font stack, gold accent, ornament divider (`application.css`).
- Stimulus controller conventions (`expand`, `reveal`) for the new `zoom` controller.
- `Painting#display_image?`, `#artist_display`, `#meta_line`, `#aspect_ratio` helpers.

## Approved Mockups
| Screen | Path | Direction | Notes |
|---|---|---|---|
| Today view | `specs/0001-daily-artwork/wireframe.html` (Option A; committed to repo per Codex #11 — gstack copy at `~/.gstack/projects/tasteMaker/designs/today-view-20260803/`) | "Gallery wall" — art leads ~55vh letterboxed, blurb peeks above fold | Theme decision 6A overlays this: linen palette, dark feed untouched |

## Failure modes (eng review)
| Codepath | Realistic failure | Test? | Handled? | User sees |
|---|---|---|---|---|
| `DailyPick.current` | server TZ ≠ ET, tomorrow leaks | yes (boundary) | yes (config.time_zone) | correct day |
| Root render, no pick today | curator missed a day | yes (fallback) | yes | yesterday's art, honest date |
| Image blob missing / CDN 404 | disk loss, museum URL rot | yes (placeholder) | yes (onerror) | "This work is resting" + blurb |
| Feed lazy frames after root swap | frames fetch daily view | yes (regression) | yes (step 6) | feed keeps scrolling |
| Preview without auth | URL guessing | yes (401 test) | yes (member route) | 401, nothing leaks |
| Stale cached page after blurb edit | broken max-age plan | yes (ETag test) | yes (no-cache) | fresh content |
| Double-schedule same date/painting | race or fat-finger | yes (dup tests) | yes (DB + validation) | inline form error |
No critical gaps: every identified failure has a test AND handling AND a visible state.

## Parallelization
Solo dev, one machine — mostly sequential. If splitting: Lane A steps 1–2 (model/TZ),
then Lane B steps 3–5 (public view/theme/zoom) ∥ Lane C step 7 (admin) — B and C share
only routes.rb (trivial conflict). Steps 6, 8–10 after lanes merge.

## Implementation Tasks
Synthesized from review findings; checkbox as shipped.
- [x] **T1 (P1)** — masthead + honest date (P1-issue1) — `daily/show.html.erb`
- [x] **T2 (P1)** — scoped linen palette, AA contrast (P4-issue6) — `application.css`
- [x] **T3 (P1)** — contain/55dvh/never-crop image treatment (P4-issue7) — view + CSS
- [x] **T4 (P1)** — fold-budget system test, bounding rect (P4-issue7) — system test
- [x] **T5 (P1)** — zoom controller + a11y contract + test (P6-issue9) — new Stimulus
- [x] **T6 (P2)** — loading: reserved box + preload (P2-issue2) — view/head
- [x] **T7 (P2)** — error/empty states + admin no-image validation (P2-issue3)
- [x] **T8 (P2)** — ETag + must-revalidate caching (P2-issue4) — controller
- [x] **T9 (P2)** — blurb contract: simple_format, no clamp, word counter (P4-issue8)
- [x] **T10 (P2)** — closing beat + honest gallery link (P3-issue5) — view
- [x] **T11 (P2)** — admin preview route + labeled select + thumbnail (P7-issue11)
- [x] **T12 (P3)** — README note (existing step)
- [x] **T13 (P1)** — set `config.time_zone` + midnight boundary test (Codex #3)
- [x] **T14 (P1)** — preview as authed member action + tests (Eng-1, Eng-2)
- [x] **T15 (P1)** — cache: `fresh_when` + no-cache, drop max-age plan (Eng-6)
- [x] **T16 (P2)** — admin edit keeps own painting in select; date default ≥ today (Codex #8, #9)
- [x] **T17 (P2)** — img `onerror` placeholder guard (Codex #10)
- [x] **T18 (P2)** — layout title/meta + PWA manifest truth pass (Codex #7)
- [x] **T19 (P2)** — enable `test:system` in bin/ci (Codex #5)
- [x] **T20 (P1, deploy-blocking)** — pre-launch content checklist: pick live + 7 queued (Codex #4)
- [x] **T21 (P2)** — eager-load painting/attachment in daily#show + admin (Eng-3)

### Post-build audit fixes (six-lens adversarial review, 2026-08-03)
27 findings raised, 22 refuted by skeptics, 4 confirmed — all P3, all fixed:
- [x] **A1** — admin painting picker was still N+1 (109 → 5 queries); T21 had missed it
- [x] **A2** — the feed lazy-frame regression the plan claimed to test was untested:
      5 fixtures vs `PER_PAGE = 10` meant the next-page frame never rendered in any test.
      Added a test that fills a second page; mutation-checked (reverting to `root_path`
      now fails it).
- [x] **A3** — admin queue table forced the whole page to scroll sideways at 375px;
      now the table scrolls inside its own container and the row links wrap
- [x] **A4** — zoom's tap-to-dismiss (the primary phone gesture) and the body scroll
      lock had no test; both added and mutation-checked

## Estimate
~2–3 days (eng review honesty pass — Codex #6; scope confirmed twice, not cut).
Fits Full lane ceiling.

## Deviations (added during build)
- **Reversed post-ship (2026-08-03): the two-skin theme is gone.** Design decision 6A
  below ("morning room / gallery at night", linen scoped to `body.daily`, dark feed
  untouched) shipped and then read as two apps side by side. The linen palette is now
  the only palette; the `.daily-*` and feed component sets merged into one vocabulary
  (`.masthead`, `.page`, `.plate`, `.label`, `.coda`). Written up in `DESIGN.md`,
  decided in `decisions/0003-one-skin.md`, enforced by `test/system/design_test.rb`.
- **Stimulus controller named `artwork`, not `zoom`.** It owns the broken-image fallback
  as well, because the two behaviours have to agree: a placeholder must not stay
  zoomable. Two controllers would have needed to coordinate that.
- **Painting picker ordered by title, not "newest first".** The curator searches for a
  work by name; recency of import is not a thing they know.
- **Global `[hidden] { display: none !important }`.** A system test caught the zoom
  trigger staying visible after an image error: `.daily-figure__zoom { display: block }`
  was overriding the `hidden` attribute. One rule kills the whole bug class, and it
  replaced the `.zoom[hidden]` special case.
- **Rails 8.1.3 → 8.1.3.1.** `bundler-audit` blocked CI on CVE-2026-66066, arbitrary file
  read / RCE in Active Storage variant processing — which is exactly the path our artwork
  images take. Patch-level bump, suite green after.
- **`artwork_src` helper extracted and used by the feed partial too.** Pure refactor, no
  behaviour change; the feed integration test now asserts the image src so the frozen
  feed stays covered.
- **Extra `picker` Stimulus controller** to make the plan's "thumbnail of selected
  painting" live rather than only-after-save.
- **CI uploads screenshots** from failed system tests, since fold-budget failures are
  only legible as pictures.
- Observed while dogfooding, not fixed (no spec, out of scope): on a phone the zoom
  overlay mostly removes chrome rather than magnifying, because the artwork already
  spans the width. Real detail comes from pinching the 1600px asset (≈4× at 390 CSS px)
  and from the overlay on desktop. Worth a look during `/qa`.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 2 (outside voices: design + eng) | issues absorbed | design: 5 findings; eng: 12 findings — 11 absorbed, 1 rejected (scope re-argument) |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAN | 3 issues (preview auth leak, 2 test gaps, N+1) + 11 Codex absorptions; 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | score: 4/10 → 9/10, 11 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** eng outside voice caught 2 review errors — broken cache semantics (max-age never revalidates → switched to no-cache+ETag) and unimplementable acceptance wording (reworded) — plus 8 mechanical gaps (TZ config commented out, CI system tests disabled, admin edit select bug, date-default ≥ today, onerror guard, metadata truth pass, pre-launch content checklist, mockup committed to repo).
**CROSS-MODEL:** design phase — both models converged on brand/zoom absence; Claude subagent uniquely caught cover-crop and theme contradiction. Eng phase — Codex #6 (cut zoom/cache scope) rejected: scope was user-confirmed at design review and the complexity gate; estimate honesty applied instead (2–3 days).
**VERDICT:** DESIGN + ENG CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
