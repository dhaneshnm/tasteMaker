# 0003 — Implementation plan
Status: Design-reviewed (`/plan-design-review` 2026-08-04 — 7 decisions, score 5/10 → 9/10).
Next gate: `/plan-eng-review`.

## Approach

The day page already exists. `daily/show` renders whatever `@pick` it is handed —
`Admin::DailyPicksController#preview` has been rendering arbitrary picks through it since
story 0001. So a past day is not a new page: it is the same template with a different
record and slightly different chrome.

Two routes, one new controller, one new view, one shared partial extracted:

```ruby
resources :days, only: %i[index show], param: :date,
  constraints: { date: /\d{4}-\d{2}-\d{2}/ }
```

- `GET /days` → `DaysController#index` — the list, newest first.
- `GET /days/2026-08-02` → `DaysController#show` — that day, `render template: "daily/show"`.

`DailyPick.published` (`scheduled_on: ..Date.current`, Eastern per `config.time_zone`)
is already the no-leak rule and is reused verbatim for both actions. A future date, an
unscheduled date, and a malformed date all end in the same 404 — no distinction, because
distinguishing them would tell a guesser which dates are queued.

**`#show` redirects to `root_path` when the date is today.** `published` is inclusive of
today, so without this `/days/2026-08-04` renders today's artwork under the label "From
the archive", with no "See you tomorrow.", and a coda link "Today →" pointing at the page
the reader is already on. One day, one canonical URL.

**Thumbnails.** `image_processing` is already in the Gemfile, so locally attached artwork
gets an Active Storage variant for the list; a painting still on the CDN fallback uses
`image_url_800`. One helper, `artwork_thumb(painting)`, next to `artwork_src`:

```ruby
painting.image.attached? ? painting.image.variant(resize_to_limit: [240, 240]) : painting.image_url_800
```

240px is 2× the largest box the list ever draws (112px). `resize_to_limit: [400, 400]`
from the first draft was oversized, and "the CDN fallback at CSS size" was a bug: an
800px JPEG drawn at 112px, thirty times, is roughly 20 MB on a phone. Rows past the
first four get `loading="lazy"`. **The variant call is wrapped in a rescue that falls
back to `artwork_src`** — vips runs inline on first request and one unreadable blob
would otherwise 500 the whole archive.

**Caching.** Same shape as the daily page: `fresh_when` + `public, no-cache`, so a blurb
edit shows immediately and an unchanged list costs a 304. The index ETag includes
`Date.current` so the list rolls over at Eastern midnight when a queued day becomes
published without any record changing.

**No pagination.** One pick per day means the list crosses 90 entries in month four.
Trigger written down rather than built: **when `DailyPick.published.count > 90`, paginate
with the same lazy Turbo frame the archive uses.** Until then a single query and a single
render, `with_artwork` so images are not an N+1.

---

## The list, specified

Approved direction: **variant A, "contents page"** (see Approved Mockups). Text leads;
the thumbnail is a recognition mark, not the subject. `/feed` is the gallery — this is
the index.

**Row anatomy.** One row per day, inside `.page` at `--measure` (42.5rem). Nothing gets
wider; a 680px column at 1280 is correct, not thin.

```
grid-template-columns: 1fr 7rem;      /* ≥ 641px — 112px thumbnail column */
grid-template-columns: 1fr 4.5rem;    /* ≤ 640px — 72px */
column-gap: 1.25rem;
padding: 1.15rem 0 1.25rem;
border-bottom: 1px solid var(--frame-edge);
```

| Element | Spec |
|---|---|
| Date | `0.72rem`, uppercase, `letter-spacing: 0.18em`, `--ink-dim`. Same treatment as `.masthead__aside`. Sits **above** the title inside the text column, never in its own grid column — a three-column row collapses at 375. |
| Title | `--serif-display`, `1.22rem`, weight 480, `line-height: 1.2`, **`--gold`**. The link. Not `.label__title` scale: plate-sized type repeated thirty times is a shouting match. |
| Artist | `0.95rem`, `--ink-dim`. `artist_display` **only — no life dates.** The longest artist string in the pool is 84 chars, and `.label__artist-dates::before { content: " · " }` was already a wrap defect on the daily page (ISSUE-001); it is not re-imported into a component with a quarter of the width. |
| Thumbnail | Height 112px / 72px, `width: auto`, `object-fit: contain`, `background: var(--bg-lift)`, `border: 1px solid var(--frame-edge)`, `alt=""`. Fixed height, free width: a 0.27 hanging scroll stays tall and narrow, a 2.85 screen stays wide and short, every text column still starts at the same x. |
| Today's row | Date reads `Today · Mon, Aug 4` with the date in `--gold`; links to `/`, not to `/days/<today>`. |

**Colour inversion, deliberate.** On the day page the title is `--ink` and the artist is
`--gold`; in this list they swap. In a list the title is the *target*; on the day page it
is the *subject*, and gold is the product's link colour. Without the inversion the only
gold in the row belongs to the one part that does not navigate, and the row reads as
static text. **This gets a line in `DESIGN.md`** per that file's own rule about new idioms.

**Never a card.** Rows are separated by a hairline and whitespace. No background fill, no
border box, no radius, no shadow, no transform — on any state, including hover. Hover
moves **only the title** to `--gold-deep`. This is written here because "row, not grid"
is not the same instruction as "not a card", and the drift is one padding declaration deep.

**No motion.** The archive's scroll-in reveal is not copied here. A dated index does not
need ceremony, and thirty rows fading up is a slower page pretending to be a nicer one.

**Month headings, always — from row one**, not "once entries cross into a second month".
One rule that is always true beats a screen that changes shape on day 30. Real `<h2>`,
`--ink-dim`, `0.72rem`, uppercase, `0.18em`, `border-bottom: 1px solid var(--hairline)`,
matching `.masthead` and `.adm__queue th`. Never sticky (rule 5).

**Date format.** `:daily` ("Mon, Aug 4") — the weekday is the load-bearing token for
somebody reconstructing which days they worked. Neither existing format carries a year,
so when an entry's year differs from the current year the year is appended in
`--ink-faint`; otherwise January's list shows "Fri, Jan 2" above "Mon, Aug 3" with no way
to tell them apart.

---

## Interaction states

| Surface | Loading | Empty | Error | Success | Partial |
|---|---|---|---|---|---|
| **The list** | No spinner. The page is one render; `.sentinel` only appears if pagination ever ships. | Zero published days: `.page--empty` + `.coda` — ornament, "The days will collect here.", `.caps-link` to the gallery. | 500 is prevented, not designed: the thumbnail variant rescues to `artwork_src`. | Rows newest first, month headings, ending in a `.coda` — ornament + "Today →". A populated list is currently the only screen in the product that would stop dead at its last row. | **Exactly one day** (the launch condition): the single row renders, followed by a `.coda` reading "One day so far. Tomorrow this becomes an archive." Deliberate thinness, not an accident. |
| **A row's thumbnail** | `loading="lazy"` past the first four; the `--bg-lift` box holds the space, so no layout shift. | — | The box collapses to the empty `--bg-lift` fill with its `--frame-edge` border and **no text**. The date, title and artist carry the row. One line of CSS, no JS: `.plate__resting` is a 2.5rem-padded panel and is absurd inside a 72px box, and adding `data-controller="artwork"` to make it work would make tapping a thumbnail open the zoom overlay instead of navigating. | Contained, uncropped. | — |
| **The entry point** | — | **Hidden while `DailyPick.published.count <= 1`.** The masthead date is not a link until there is more than today to see. A door that opens onto the room you are standing in is worse than no door. | — | The date in the front door's masthead is `--gold` and links to `/days`. | — |
| **A past day** | Unchanged from the daily page. | — | A date with no pick, a future date, a malformed date: all 404, all to the **linen 404** below. | The day's own artwork, note and date, with the archive chrome. | — |
| **404** | — | — | `.page--empty` + `.coda`: ornament, "There was no artwork on that day.", `.caps-link` to `/days`. Routed through the app (`config.exceptions_app` + an `ErrorsController`) so it gets the layout and the token file — a static `public/404.html` cannot reach the asset pipeline and would need a second copy of the palette. | — | — |

**A gap in the sequence is never rendered.** `DailyPick`'s own header comment shows gaps
are normal. The list shows Aug 1 then Aug 3 with nothing between, because *a day with no
pick was never shown to anyone, so it was never missed* — the front door held the previous
pick over. Placeholder rows would advertise the curator's misses and invite the calendar
the story puts out of scope. Written here so nobody builds one.

---

## Responsive

One row shape at every width. The breakpoint changes exactly one thing.

| | ≤ 640px | ≥ 641px |
|---|---|---|
| Thumbnail column | 4.5rem (72px) | 7rem (112px) |
| Text column | remainder | remainder |
| Row height | driven by the title; measured 126–173px in the mockup | driven by the title |
| Month heading | full width, unchanged | unchanged |

Desktop has 680px of column and no density pressure; the phone has neither. Five days
per phone screen is what won this layout over the corridor and the stacked plates, and
the 112px desktop thumbnail is what stops the mark being decorative where there is room.

**Row height is whatever the title needs. No clamp, no ellipsis, no `text-overflow`.**
Rule 3 is "never truncate a title" and this component is where it gets violated, because
the fastest fix for an ugly row is `-webkit-line-clamp` and that CSS is already in
`application.css` one copy-paste away. Titles run to 104 characters in the pool (18 of
110 are over 60). Instead: `.days__title--long` at `0.92rem`, reusing the existing
`Painting#long_title?` predicate — the same step-down pattern the day page already uses.

---

## Accessibility

- `<ol>` / `<li>`. The list is ordered; a screen reader should announce "list, 14 items".
- **Each row is one `<a>`** whose accessible name is the full date, title and artist:
  "Monday, August 3: Olive Trees, Vincent van Gogh" (`:daily_long` in the name, `:daily`
  on screen). A list of bare titles is useless to somebody navigating by link, and a list
  of bare dates is worse.
- The visible date is `<time datetime="2026-08-03">`.
- Thumbnails are `alt=""` — decorative here, because the link already names the work.
  Otherwise every row is announced twice.
- Month names are real `<h2>` elements, so the list is navigable by heading.
- `:focus-visible` uses the existing global gold outline. No custom focus style.
- Touch target: rows measure 126–173px tall, comfortably past 44px. No change needed,
  but the row — not the title — is the hit area.
- Contrast, from the token table: `--gold` on paper 5.3:1, `--ink-dim` 6.0:1,
  `--ink-faint` 5.1:1. All AA at the sizes used here.
- No motion to reduce; nothing to gate behind `prefers-reduced-motion` on this screen.

---

## The journey

| Step | User does | User feels | What supports it |
|---|---|---|---|
| 1 | Opens the app after three shifts | mild dread — "I've lost the week" | Front door shows today, unchanged. Ritual first. |
| 2 | Notices the date is a link | curiosity | The date is the only new affordance, and it is the one element that already meant "which day" |
| 3 | Lands on the list | **relief** — "it's all still here" | Newest first, five days visible on a phone, months as structure |
| 4 | Scans for the days they missed | **recognition** — "oh, *that* one" | 112/72px uncropped thumbnails; weekday in the date, which is how shift workers reconstruct a week |
| 5 | Opens one | absorption | Same day page as the front door, full note, zoom |
| 6 | Walks to the next missed day | momentum | `← Previous day` / `Next day →` in the coda — three days is a three-tap walk, not nine taps with three returns |
| 7 | Reaches today | **re-entry** — "caught up, see you tomorrow" | "Today →" in the coda returns to the ritual |

The success signal in the story measures two taps to **one** day. The persona misses
**three**. Step 6 is the difference between passing the metric and serving the user.

---

## Chrome fork

`daily/show` hard-codes "Artwork of the Day" and "See you tomorrow." Neither is true on a
past day. Extract the body into `daily/_day.html.erb` with a `front_door:` local. The
admin preview keeps rendering with `front_door: true`, which is what a curator previews.

| | front door (`/`) | a past day (`/days/:date`) | the list (`/days`) |
|---|---|---|---|
| masthead label | Artwork of the Day | From the archive | Past days |
| masthead aside | the pick's date — **links to `/days`** once more than one day is published | that day's date — links to `/days` | the count: "14 days" |
| coda line | See you tomorrow. | (none) | Today → |
| coda links | Wander the full gallery → | ← Previous day · Next day → · Today → | Wander the full gallery → |

The date is the door on every screen that has one. The first draft justified keeping the
entry point out of the masthead by citing rule 5 — that was **wrong**: rule 5 governs
overlays and stickiness, the masthead is explicitly non-sticky, and `.masthead__brand` is
already a link on both existing screens. That sentence is struck.

Prev/next are bounded by the published range: the oldest day has no previous, today's
neighbour is the front door.

---

## Steps

1. Extract `daily/_day.html.erb` from `daily/show` with a `front_door:` local; point
   `daily/show` and the admin preview at it. Behaviour unchanged, suite green.
2. `DaysController#show` + route + the today-redirect + the 404 paths. Tests for the leak
   rule first.
3. `ErrorsController` + `config.exceptions_app` + the linen 404 view.
4. `artwork_thumb` helper: variant at `[240, 240]`, CDN fallback, rescue → `artwork_src`.
5. `days/index.html.erb` + `.days` CSS exactly as specified above. Add the component and
   the colour inversion to `DESIGN.md`; add a Claude Design card for it.
6. Entry points: the masthead date links to `/days` when `published.count > 1`; prev/next
   and "Today →" in the past-day coda.
7. `bin/ci` green, then dogfood at 1280 and 375 with at least four published days seeded,
   including one 100+ character title and one aspect ratio under 0.4.

---

## Tests

Integration (`test/integration/days_test.rb`):
- the list shows published days newest first, and today is in it, labelled and linking to `/`;
- a queued future day is absent from the list **and** its URL 404s (the leak rule, both halves);
- a malformed date and an unscheduled past date both 404, and the 404 renders the linen page;
- `/days/<today>` redirects to `root_path`;
- a past day renders that day's artwork, that day's note, and that day's date — not today's;
- the list revalidates: same request twice costs a 304, an edited blurb does not;
- the zero-day empty state renders;
- **the one-day list renders its own coda** and the front door's date is **not** a link;
- with two or more days, the front door's date **is** a link to `/days`;
- prev/next appear on a past day and stop at the ends of the published range;
- a 104-character title renders without a clamp and picks up `--long`;
- rows are `<li>` inside `<ol>`, and each row's link name carries date + title + artist.

System (`test/system/days_test.rb`):
- from the front door, two taps reach a past day;
- three missed days are walkable with next/previous without returning to the list;
- zoom works on a past day (same plate — the parity guard);
- a thumbnail that errors leaves its row intact and still navigable;
- at 375 the row keeps its shape and the title does not clamp.

Model: `DailyPick.published` already carries story 0001's midnight-boundary coverage;
this story adds no new date rule. Any new predicate (`previous_day` / `next_day`) gets a
boundary test next to the existing ones.

---

## Risks

- **Nearly empty at launch.** One published day today. Answered by the state table: the
  entry point stays hidden until day two, and the one-day list carries its own coda.
- **Vips runs inline on first request.** Named as a perf risk in the first draft; the
  real risk was availability — one unreadable blob would 500 the archive. Rescued to
  `artwork_src`. If the list ever feels slow before pagination arrives, the fix is a
  variant-warming job, not a bigger page. Named, not built.
- **Two templates drifting.** The front door and a past day share `_day.html.erb`, so
  they cannot; the guard is the existing daily system test plus the new zoom parity test.
- **The clamp is one copy-paste away.** `.label__text` already has `-webkit-line-clamp: 4`
  in the same stylesheet. Mitigation is the written rule above plus the 104-char test.

---

## NOT in scope (design decisions considered, deferred with rationale)

- **Calendar / month grid.** A list answers "what did I miss"; a calendar answers a
  different question and would need the gap-rendering this plan explicitly forbids.
- **Search or filter by artist.** The list is short for months. Revisit past ~90 days,
  alongside pagination.
- **A "save" affordance on rows.** Favourites is baseline item 4 with its own story;
  putting a half-version here would prejudge device-local vs accounts.
- **Sticky month headings.** Rule 5. A heading that follows you is chrome over the work.
- **Scroll-reveal on rows.** Considered for consistency with the archive; rejected — the
  archive is a gallery walk, this is an index, and motion here is ceremony.
- **A larger thumbnail on desktop than 112px.** Considered; past that the list starts
  becoming variant C, which is `/feed` with dates.
- **Pagination.** Trigger written down (`published.count > 90`), not built.

## What already exists (reuse, don't reinvent)

| Need | Already in the repo |
|---|---|
| The day page | `daily/show` — renders any `@pick`; the admin preview proves it |
| The no-leak rule | `DailyPick.published`, Eastern-aware, boundary-tested |
| Page shell | `.masthead`, `.page`, `.page--empty`, `.coda`, `.ornament`, `.caps-link` |
| Artwork treatment | `.plate__img` — `contain`, `--bg-lift` fill, `--frame-edge` border |
| Long titles | `Painting#long_title?` (60 chars) and the `--long` step-down pattern |
| Date formats | `Date::DATE_FORMATS[:daily]` and `[:daily_long]` |
| Image variants | `image_processing` already in the Gemfile |
| Future pagination | `.sentinel` + the archive's lazy Turbo frame |
| A precedent to avoid | `admin/daily_picks#index` is already a list of days — Date · Title · muted artist. The public list must not be a reskin of the curator's table, which is why the picture and the gold title carry the row |

## Approved Mockups

| Screen | Mockup | Direction | Notes |
|---|---|---|---|
| `/days` list, 1280 | `~/.gstack/projects/tasteMaker/designs/past-days-list-20260804/variant-a-contents.png` | "Contents page" — text leads, thumbnail is a recognition mark on the right | Built in the real design system with real MIA works, including a 0.27 scroll and a 2.85 screen. Thumbnail grows to 112px per D9 |
| `/days` list, 375 | `~/.gstack/projects/tasteMaker/designs/past-days-list-20260804/variant-a-contents-375.png` | Same row, 72px thumbnail | Measured 126–173px rows, ~5 days per screen |
| Rejected: corridor | `…/variant-b-corridor.png` | Image-led, 132px thumb left | Titles wrap to four lines at 375; density drops to three days |
| Rejected: stacked plates | `…/variant-c-plates.png` | Full plates with dates | ~1.5 days per screen; duplicates `/feed`'s job |

## Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific finding above.

- [ ] **T1 (P1, human: ~45min / CC: ~10min)** — `days/index.html.erb` + `.days` CSS — build the row exactly as specified
  - Surfaced by: Pass 1 + Pass 4 — row anatomy was four nouns and one token reference
  - Files: `app/views/days/index.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: `bin/rails test test/integration/days_test.rb`, then dogfood at 1280/375
- [ ] **T2 (P1, human: ~30min / CC: ~10min)** — `DaysController` — index, show, today-redirect, 404 paths
  - Surfaced by: Pass 3 (J3) — `/days/<today>` would be a second URL for one day, mislabelled
  - Files: `app/controllers/days_controller.rb`, `config/routes.rb`
  - Verify: leak-rule and redirect tests in `test/integration/days_test.rb`
- [ ] **T3 (P1, human: ~30min / CC: ~10min)** — entry point — masthead date links to `/days` only when `published.count > 1`
  - Surfaced by: Pass 2 (D6) — launch day would offer a door onto the room you are in
  - Files: `app/views/daily/_day.html.erb`, `app/controllers/daily_controller.rb`
  - Verify: both halves of the gating test
- [ ] **T4 (P1, human: ~20min / CC: ~5min)** — no-clamp rule + `--long` step-down at list scale
  - Surfaced by: Pass 6 (A1) — 104-char titles in the pool, clamp CSS one copy-paste away
  - Files: `app/views/days/index.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: 104-character title test
- [ ] **T5 (P1, human: ~30min / CC: ~10min)** — `artwork_thumb` — 240px variant, CDN fallback, rescue to `artwork_src`
  - Surfaced by: Pass 2 (S6) — 800px images at 112px, and vips failure 500ing the archive
  - Files: `app/helpers/application_helper.rb`
  - Verify: helper test with an unreadable blob
- [ ] **T6 (P2, human: ~30min / CC: ~10min)** — accessibility — `<ol>`/`<li>`, full link names, `<time datetime>`, `alt=""`, `<h2>` months
  - Surfaced by: Pass 6 (D11) — the plan contained no a11y specification at all
  - Files: `app/views/days/index.html.erb`
  - Verify: link-name and list-structure tests
- [ ] **T7 (P2, human: ~40min / CC: ~15min)** — prev/next day in the past-day coda, bounded by the published range
  - Surfaced by: Pass 3 (D8) — catching up on three days cost nine taps
  - Files: `app/models/daily_pick.rb`, `app/views/daily/_day.html.erb`
  - Verify: boundary tests at both ends; system test walking three days
- [ ] **T8 (P2, human: ~30min / CC: ~10min)** — linen 404 via `ErrorsController` + `exceptions_app`
  - Surfaced by: Pass 2 (D7) — the only non-linen screen, reached by design
  - Files: `app/controllers/errors_controller.rb`, `config/application.rb`, `app/views/errors/not_found.html.erb`
  - Verify: integration test asserting the linen 404 body on an unscheduled date
- [ ] **T9 (P2, human: ~20min / CC: ~5min)** — one-day and zero-day states with their codas
  - Surfaced by: Pass 2 (S1, S4) — five of six states unspecified
  - Files: `app/views/days/index.html.erb`
  - Verify: one-day coda test, empty-state test
- [ ] **T10 (P2, human: ~15min / CC: ~5min)** — `DESIGN.md`: the contents-list component, the colour inversion, the card ban
  - Surfaced by: Pass 5 (D10) + both outside voices — undocumented inversion drifts
  - Files: `DESIGN.md`
  - Verify: `bin/rails test test/system/design_test.rb`
- [ ] **T11 (P3, human: ~15min / CC: ~5min)** — year suffix on dates from a previous year
  - Surfaced by: Pass 4 (J5) — neither date format carries a year
  - Files: `app/helpers/application_helper.rb`, `app/views/days/index.html.erb`
  - Verify: freeze-time test across a year boundary
- [ ] **T12 (P3, human: ~10min / CC: ~5min)** — seed four days with a 100+ char title and a sub-0.4 aspect ratio for dogfooding
  - Surfaced by: Pass 6 — the stress cases are in the pool and should be on screen during QA
  - Files: `db/seeds.rb`
  - Verify: manual, at 375

## Deviations (added during build)
- <date>: <what changed vs plan, why>

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 (design outside voice) | issues absorbed | 8 findings, 0 hard rejections, litmus 7/7 on direction |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 (for this plan) | NOT RUN | last run 2026-08-03 against story 0001, 9 commits ago |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | score: 5/10 → 9/10, 7 decisions, 12 tasks |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** classified APP UI, no hard rejection, and named the same three gaps the passes
found independently — undefined interaction states, no 375px composition, incomplete link
semantics. Its "ban cards in writing" and "lock the thumbnail box" both landed in the plan.

**CROSS-MODEL:** Codex and the Claude subagent converged on the navigation model (both
proposed the masthead date as the door, which was also D5's answer) and diverged on litmus
2 — Codex read the dated list as a sufficient visual anchor, the subagent argued the
picture must lead and produced aspect-ratio and title-length measurements from the seed
data to prove the row would break. The measurements decided D9 and D11. The subagent also
caught two things neither Codex nor the first-party passes did: `/days/<today>` being a
second, mislabelled URL for one day, and the plan's rule-5 justification being factually
wrong.

**VERDICT:** DESIGN CLEARED — 7 decisions resolved, 0 deferred. Eng review required
before implementation.

NO UNRESOLVED DECISIONS
