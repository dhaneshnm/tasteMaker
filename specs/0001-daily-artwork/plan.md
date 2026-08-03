# 0001 — Implementation plan
Status: Design-reviewed (/plan-design-review, 2026-08-03) — pending /plan-eng-review

## Approach
New `DailyPick` model joins a `Painting` to a calendar date and carries the curator's
hand-written blurb (separate from `paintings.description`, which is museum copy). Root
route becomes the today view; the feed moves to `/feed` untouched (decision 0002). A
minimal HTTP-basic-authed admin lets the curator queue future days. No new gems, no
Solid Queue yet — nothing here needs a job; the "publish" event is just `scheduled_on`
arriving.

## Data
`daily_picks`:
- `painting_id` — FK, null: false, unique (a painting is featured at most once)
- `scheduled_on` — date, null: false, unique (one pick per day)
- `blurb` — text, null: false (hand-written; no generated text on this path)

Model: `belongs_to :painting`; validations mirror the constraints; additionally a
painting failing `display_image?` cannot be scheduled (keeps the broken-image state
nearly unreachable). `DailyPick.current` → pick with latest `scheduled_on <=
Date.current` (fallback for unscheduled days comes free: yesterday's pick stays up,
honestly dated — see masthead).

## "Today" rule (Better bar 5)
**Confirmed at design review:** day rolls at midnight `America/New_York`
(`config.time_zone`). Maya's persona is Columbus = Eastern. No per-visitor timezone
logic. No tomorrow-leak: `current` never selects `scheduled_on > Date.current`.

## Routes
- `root "daily#show"` (was `paintings#index`)
- `get "feed" => "paintings#index"` — feed reachable, frozen; fix its lazy-frame
  next-page URLs if they assume root
- `namespace :admin { resources :daily_picks, except: :show }` plus
  `get "admin/daily_picks/:id/preview"` → renders the pick through the public
  `daily#show` view (curator sees exact fold behavior before publishing)

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
11. **Caching** — `Cache-Control: public, max-age=<seconds to EOD ET>,
    must-revalidate` + ETag on `[pick.id, pick.updated_at]`. Typo fixes revalidate
    instantly; no stale art after midnight.

### Interaction states
| Feature | Loading | Empty | Error | Success |
|---|---|---|---|---|
| Today artwork | reserved linen box, no CLS | pre-launch: wordmark + "The first artwork arrives soon." | image missing/404: framed placeholder "This work is resting — read today's note", title+blurb still render | art + blurb co-visible |
| Zoom overlay | instant (same asset) | n/a | n/a | full-bleed, Escape/tap closes |
| Admin form | n/a | empty select = all paintings picked, say so | duplicate date / picked painting / no-image: inline messages naming the field | redirect to queue, flash confirms date |

## Screens
1. **Today** (`daily#show`): per design spec above.
2. **Admin queue** (`admin/daily_picks`): `http_basic_authenticate_with`, password in
   Rails credentials. Index = upcoming + past picks. Form: painting select labeled
   "Title — Artist (Year)" (unpicked only, newest first) + thumbnail of selected
   painting, date field defaulting to first unscheduled date, blurb textarea with
   live word count + soft warning outside 60–180 words. Clear inline validation
   errors. Preview link per pick (renders public view). Plain otherwise — curator is
   the only user.

## Steps
1. Migration + `DailyPick` model (incl. `display_image?` schedulability validation) +
   fixtures + model tests.
2. Linen palette scoped to `body.daily` (CSS variables, AA-checked values).
3. `DailyController#show` + view per design spec + ETag/cache headers + integration
   tests + system tests (fold-budget bounding-rect assert; fallback day; empty state).
4. `zoom` Stimulus controller + overlay + system test (open, Escape-dismiss).
5. Route move: root swap, `/feed`, fix feed frame URLs; test feed still paginates.
6. Admin controller + views (labeled select, thumbnail, word count, errors, preview
   route) + auth + tests (401 without credentials; create/edit; duplicate rejection).
7. README root-URL note; `bin/ci` green.

## Tests
- Model: unique date, unique painting, blurb presence, no-image schedulability
  rejection, `current` selection incl. no-future-leak.
- Integration: root renders today's pick; unscheduled day falls back with honest
  date; feed at `/feed` paginates; admin 401 without credentials; admin create;
  duplicate-date error; ETag revalidation (304 on match, fresh after update).
- System (Capybara): fold budget at 375×667 (blurb rect in viewport); zoom
  open/dismiss; empty-state copy.

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
| Today view | `~/.gstack/projects/tasteMaker/designs/today-view-20260803/wireframe.html` (Option A) + `approved.json` | "Gallery wall" — art leads ~55vh letterboxed, blurb peeks above fold | Theme decision 6A overlays this: linen palette, dark feed untouched |

## Implementation Tasks
Synthesized from review findings; checkbox as shipped.
- [ ] **T1 (P1)** — masthead + honest date (P1-issue1) — `daily/show.html.erb`
- [ ] **T2 (P1)** — scoped linen palette, AA contrast (P4-issue6) — `application.css`
- [ ] **T3 (P1)** — contain/55dvh/never-crop image treatment (P4-issue7) — view + CSS
- [ ] **T4 (P1)** — fold-budget system test, bounding rect (P4-issue7) — system test
- [ ] **T5 (P1)** — zoom controller + a11y contract + test (P6-issue9) — new Stimulus
- [ ] **T6 (P2)** — loading: reserved box + preload (P2-issue2) — view/head
- [ ] **T7 (P2)** — error/empty states + admin no-image validation (P2-issue3)
- [ ] **T8 (P2)** — ETag + must-revalidate caching (P2-issue4) — controller
- [ ] **T9 (P2)** — blurb contract: simple_format, no clamp, word counter (P4-issue8)
- [ ] **T10 (P2)** — closing beat + honest gallery link (P3-issue5) — view
- [ ] **T11 (P2)** — admin preview route + labeled select + thumbnail (P7-issue11)
- [ ] **T12 (P3)** — README note (existing step)

## Estimate
~2 days (was ~1; zoom + admin polish + state coverage added). Fits Full lane.

## Deviations (added during build)
- (none yet)

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 (via design outside voices) | issues absorbed | 5 findings, 1 hard rejection — all resolved into plan |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | — | pending |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | score: 4/10 → 9/10, 11 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** flagged weak first-screen brand (hard rejection), missing zoom, thin art-direction spec, admin friction — all 5 findings absorbed as decisions 1, 9, 6/7, 11.
**CROSS-MODEL:** Codex and blind Claude subagent independently converged on brand-absence and zoom-absence; Claude subagent uniquely caught the object-fit:cover crop hazard and the linen-vs-dark theme contradiction — both resolved (decisions 7, 6).
**VERDICT:** DESIGN CLEARED (4/10 → 9/10, 11/11 decisions resolved) — eng review required before build.

NO UNRESOLVED DECISIONS
