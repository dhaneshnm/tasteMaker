# 0003 — Implementation plan
Status: Design-reviewed (`/plan-design-review` 2026-08-04 — 7 decisions, 5/10 → 9/10) and
Eng-reviewed (`/plan-eng-review` 2026-08-04 — 9 findings, scope reduced, 0 critical gaps).
Built 2026-08-04 — all 15 tasks done, bin/ci green, dogfooded at 1280 and 375.

## Approach

The day page already exists. `daily/show` renders whatever `@pick` it is handed —
`Admin::DailyPicksController#preview` has been rendering arbitrary picks through it since
story 0001. So a past day is not a new page: it is the same template with a different
record and different chrome.

Two routes, one new controller, one new view, one shared partial extracted:

```ruby
resources :days, only: %i[index show], param: :date,
  constraints: { date: /\d{4}-\d{2}-\d{2}/ }
```

- `GET /days` → `DaysController#index` — the list, newest first.
- `GET /days/2026-08-02` → `DaysController#show` — that day, `render template: "daily/show"`.

### The current pick, not "today"

**The load-bearing correction from eng review.** `DailyPick.current` returns the most
recent *published* pick, which on a gap day is not today's:

```ruby
# app/models/daily_pick.rb:34
def self.current
  published.order(scheduled_on: :desc).first
end
```

Story 0001 built that hold-over deliberately and tested it. Every rule in this story
therefore keys on **the pick the front door is showing**, never on `Date.current`:

| Rule | Wrong (keys on the calendar) | Right (keys on the current pick) |
|---|---|---|
| `#show` redirect | redirect when `date == Date.current` | redirect when `date == DailyPick.current.scheduled_on` |
| The list's front-door row | label the `Date.current` row "Today" | link the **current pick's** row to `/`; label it "Today ·" only when its date genuinely is today |
| "Today →" in a coda | always shown | hidden when the reader is already on the current pick |
| Prev/next | neighbours of `Date.current` | neighbours within `published`, which is already gap-tolerant |

Without this, on a day with no pick `/days/2026-08-04` would redirect to `/` while `/` is
showing Aug 2 — a URL for a day with no artwork silently landing on a different day's
artwork — and the reader standing on `/days/2026-08-02` would see a "Today →" link to the
painting already in front of them. Gap days are exactly when somebody goes looking for
the archive, so this is the wrong place to be approximately right.

`DailyPick.published` (`scheduled_on: ..Date.current`, Eastern per `config.time_zone`) is
still the no-leak rule and is reused verbatim. A future date and an unscheduled date both
404, with no distinction — distinguishing them would tell a guesser which dates are queued.

### Request flow

```
                         GET /                          GET /days                 GET /days/:date
                            |                               |                            |
                   DailyController#show            DaysController#index         DaysController#show
                            |                               |                            |
                   pick = DailyPick.current         picks = published            date parses?
                            |                        .with_artwork.desc            |        |
                   pick.nil? --yes--> :empty                |                     no       yes
                            |                        group_by(month)               |        |
                            no                              |                    404   published?
                            |                        fresh_when([picks,             |    |      |
                   fresh_when([pick,                   paintings.max])              |   no     yes
                     published.count])                      |                       |    |      |
                            |                        count == 0 -> empty coda       |  404   date ==
                   render _day(chrome: :front_door)  count == 1 -> thin coda        |        current.
                            |                        count >  1 -> normal coda      |      scheduled_on?
                   date links to /days                                              |        |      |
                   only when count > 1                                              |      yes     no
                                                                                    |       |       |
                                                                          redirect to /   render _day(
                                                                                          chrome: :archive)
```

### The shared day partial

`daily/show` hard-codes "Artwork of the Day" and "See you tomorrow." Neither is true on a
past day. Extract the body into `daily/_day.html.erb` taking **`chrome:`** — a symbol, not
a boolean, because there are three callers and four things that vary:

| | `:front_door` (`/`) | `:archive` (`/days/:date`) | `:preview` (admin) |
|---|---|---|---|
| masthead label | Artwork of the Day | From the archive | Artwork of the Day |
| masthead aside | the pick's date, **links to `/days`** when `published.count > 1` | that day's date, links to `/days` | the pick's date, **not a link** |
| coda line | See you tomorrow. | (none) | See you tomorrow. |
| coda links | Wander the full gallery → | ← Previous day · Next day → · Today → | Wander the full gallery → |

`:preview` exists because a curator previewing a queued day should see the page readers
will see, not a page with a live archive link that means nothing in a preview.

**The next-day link skips the redirect.** When the next published day is the current pick,
the link target is `root_path`, not `day_path(...)` — otherwise the last step of every
catch-up walk pays a 301 and briefly shows a URL that is not canonical.

**"Today →" hides when the reader is already on the current pick.** Same self-link rule.

### Thumbnails — one helper, not two

`artwork_src` already owns the attached-or-CDN fork. It gains a size instead of growing a
twin:

```ruby
# app/helpers/application_helper.rb
def artwork_src(painting, size: nil)
  return painting.image_url_800 unless painting.image.attached?
  return url_for(painting.image) if size.nil?

  painting.image.variant(resize_to_limit: [ size, size ])
rescue ActiveStorage::Error, Vips::Error => e
  Rails.logger.warn("[artwork_src] variant failed for painting #{painting.id}: #{e.class}")
  painting.image_url_800
end
```

240 for the list (2× the largest box drawn, 112px). Not 400 — and not "the CDN fallback at
CSS size", which was an 800px JPEG drawn at 112px, thirty times, roughly 20 MB on a phone.
Rows past the first four get `loading="lazy"`.

The rescue is **narrow and logged**. A bare `rescue` would also swallow programmer errors,
and because the fallback works, a wholly broken variant pipeline would look healthy while
serving full-size images forever.

### Caching

Both pages: `fresh_when` + `public, no-cache`, so an edit shows immediately and an
unchanged page costs a 304.

- **Front door:** `fresh_when([@pick, DailyPick.published.count], public: true)`. The count
  is in the key because D6 makes the page depend on it. Without it, a curator backfilling a
  *past* day leaves `current` unchanged, so every returning visitor gets a 304 and never
  sees the archive link that now exists.
- **The list:** the key covers the picks **and the paintings they render** —
  `fresh_when([@picks, Painting.where(id: @picks.map(&:painting_id)).maximum(:updated_at)])`.
  Rows show `title`, `artist_display` and the image, which live on a different table with
  their own timestamps; keying on picks alone means a re-seed corrects a title and returning
  visitors keep the old one. Compute this from the **relation**, before grouping — a Hash
  has no cache key.

### No pagination

One pick per day means the list crosses 90 entries in month four. Trigger written down
rather than built: **when `DailyPick.published.count > 90`, paginate with the same lazy
Turbo frame the archive uses.** Until then one query and one render, `with_artwork` so
images are not an N+1.

---

## The list, specified

Approved direction: **variant A, "contents page"** (see Approved Mockups). Text leads; the
thumbnail is a recognition mark, not the subject. `/feed` is the gallery — this is the index.

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
| The current pick's row | Links to `/`, date in `--gold`. Prefixed `Today · ` only when its date really is today. |

**Colour inversion, deliberate.** On the day page the title is `--ink` and the artist is
`--gold`; in this list they swap. In a list the title is the *target*; on the day page it is
the *subject*, and gold is the product's link colour. Without the inversion the only gold in
the row belongs to the one part that does not navigate, and the row reads as static text.
**This gets a line in `DESIGN.md`** per that file's own rule about new idioms.

**Never a card.** Rows are separated by a hairline and whitespace. No background fill, no
border box, no radius, no shadow, no transform — on any state, including hover. Hover moves
**only the title** to `--gold-deep`. Written here because "row, not grid" is not the same
instruction as "not a card", and the drift is one padding declaration deep.

**No motion.** The archive's scroll-in reveal is not copied here. A dated index does not need
ceremony, and thirty rows fading up is a slower page pretending to be a nicer one.

**Month headings, always — from row one**, not "once entries cross into a second month". One
rule that is always true beats a screen that changes shape on day 30. Real `<h2>`,
`--ink-dim`, `0.72rem`, uppercase, `0.18em`, `border-bottom: 1px solid var(--hairline)`,
matching `.masthead` and `.adm__queue th`. Never sticky (rule 5). **Grouped in
`DaysController#index`**, not in the template — the view is a loop over groups.

**Date format.** `:daily` ("Mon, Aug 4") — the weekday is the load-bearing token for somebody
reconstructing which days they worked. Neither existing format carries a year, so when an
entry's year differs from the current year the year is appended in `--ink-faint`; otherwise
January's list shows "Fri, Jan 2" above "Mon, Aug 3" with no way to tell them apart.

---

## Interaction states

| Surface | Loading | Empty | Error | Success | Partial |
|---|---|---|---|---|---|
| **The list** | No spinner. One render; `.sentinel` only appears if pagination ever ships. | Zero published days: `.page--empty` + `.coda` — ornament, "The days will collect here.", `.caps-link` to the gallery. | 500 is prevented, not designed: the thumbnail variant rescues to the CDN URL and logs. | Rows newest first, month headings, ending in a `.coda` — ornament + "Today →". | **Exactly one day** (the launch condition): the single row renders, followed by a `.coda` reading "One day so far. Tomorrow this becomes an archive." Deliberate thinness, not an accident. |
| **A row's thumbnail** | `loading="lazy"` past the first four; the `--bg-lift` box holds the space, so no layout shift. | — | The box collapses to the empty `--bg-lift` fill with its `--frame-edge` border and **no text**. The date, title and artist carry the row. One line of CSS, no JS: `.plate__resting` is a 2.5rem-padded panel and is absurd inside a 72px box, and adding `data-controller="artwork"` to make it work would make tapping a thumbnail open the zoom overlay instead of navigating. | Contained, uncropped. | — |
| **The entry point** | — | **Hidden while `DailyPick.published.count <= 1`.** The masthead date is not a link until there is more than the current pick to see. A door that opens onto the room you are standing in is worse than no door. | — | The date in the front door's masthead is `--gold` and links to `/days`. | — |
| **A past day** | Unchanged from the daily page. | — | Future date, unscheduled date, malformed date: all 404 (status only in this story — the linen 404 body is story 0004). | The day's own artwork, note and date, with archive chrome. | — |
| **A gap day** | — | — | — | `/` holds the previous pick over, dated honestly (story 0001). The list links **that** row to `/`, unlabelled — "Today ·" is only for a row whose date is actually today. | `/days/<the gap date>` 404s: no pick, no page. |

**A gap in the sequence is never rendered as a row.** `DailyPick`'s own header comment shows
gaps are normal. The list shows Aug 1 then Aug 3 with nothing between, because *a day with no
pick was never shown to anyone, so it was never missed* — the front door held the previous
pick over. Placeholder rows would advertise the curator's misses and invite the calendar the
story puts out of scope.

---

## Responsive

One row shape at every width. The breakpoint changes exactly one thing.

| | ≤ 640px | ≥ 641px |
|---|---|---|
| Thumbnail column | 4.5rem (72px) | 7rem (112px) |
| Text column | remainder | remainder |
| Row height | driven by the title; measured 126–173px in the mockup | driven by the title |
| Month heading | full width, unchanged | unchanged |

Desktop has 680px of column and no density pressure; the phone has neither. Five days per
phone screen is what won this layout over the corridor and the stacked plates, and the 112px
desktop thumbnail is what stops the mark being decorative where there is room.

**Row height is whatever the title needs. No clamp, no ellipsis, no `text-overflow`.** Rule 3
is "never truncate a title" and this component is where it gets violated, because the fastest
fix for an ugly row is `-webkit-line-clamp` and that CSS is already in `application.css` one
copy-paste away. Titles run to 104 characters in the pool (18 of 110 are over 60). Instead:
`.days__title--long` at `0.92rem`, reusing the existing `Painting#long_title?` predicate.

---

## Accessibility

- `<ol>` / `<li>`. The list is ordered; a screen reader should announce "list, 14 items".
- **Each row is one `<a>`** whose accessible name is the full date, title and artist:
  "Monday, August 3: Olive Trees, Vincent van Gogh" (`:daily_long` in the name, `:daily` on
  screen). A list of bare titles is useless to somebody navigating by link.
- The visible date is `<time datetime="2026-08-03">`.
- Thumbnails are `alt=""` — decorative here, because the link already names the work.
- Month names are real `<h2>` elements, so the list is navigable by heading.
- `:focus-visible` uses the existing global gold outline. No custom focus style.
- Touch target: rows measure 126–173px, past 44px. The row — not the title — is the hit area.
- Contrast, from the token table: `--gold` 5.3:1, `--ink-dim` 6.0:1, `--ink-faint` 5.1:1.
- No motion to reduce on this screen.

---

## The journey

| Step | User does | User feels | What supports it |
|---|---|---|---|
| 1 | Opens the app after three shifts | mild dread — "I've lost the week" | Front door shows the current pick, unchanged. Ritual first. |
| 2 | Notices the date is a link | curiosity | The date is the only new affordance, and it already meant "which day" |
| 3 | Lands on the list | **relief** — "it's all still here" | Newest first, five days visible on a phone, months as structure |
| 4 | Scans for the days they missed | **recognition** — "oh, *that* one" | 112/72px uncropped thumbnails; weekday in the date, which is how shift workers reconstruct a week |
| 5 | Opens one | absorption | Same day page as the front door, full note, zoom |
| 6 | Walks to the next missed day | momentum | `← Previous day` / `Next day →` — three days is a three-tap walk, not nine taps with three returns |
| 7 | Reaches the current pick | **re-entry** — "caught up, see you tomorrow" | "Today →" returns to the ritual, and hides once they are on it |

The success signal in the story measures two taps to **one** day. The persona misses
**three**. Step 6 is the difference between passing the metric and serving the user.

---

## Steps

1. Extract `daily/_day.html.erb` from `daily/show` with the `chrome:` symbol; point
   `daily/show`, and the admin preview (`chrome: :preview`), at it. Behaviour unchanged
   except the preview losing a link it should not have had. Suite green.
2. `artwork_src(painting, size:)` — variant, CDN fallback, narrow logged rescue. Callers
   unchanged (the plate passes no size).
3. `DaysController#show` + route + the current-pick redirect + the 404 paths. Leak-rule
   tests first.
4. `DailyPick#previous_published` / `#next_published`, bounded by `published`.
5. `DaysController#index` — query, month grouping, ETag over picks **and** paintings.
6. `days/index.html.erb` + `.days` CSS exactly as specified. Add the component and the
   colour inversion to `DESIGN.md`; add a Claude Design card for it.
7. Entry points: the masthead date links to `/days` when `published.count > 1`; the front
   door's ETag gains the count; prev/next and "Today →" in the archive coda.
8. `bin/ci` green, then dogfood at 1280 and 375 with at least four published days seeded,
   including one 100+ character title, one aspect ratio under 0.4, and one gap day.

---

## Tests

Integration (`test/integration/days_test.rb`):
- the list shows published days newest first, and the current pick's row links to `/`;
- a queued future day is absent from the list **and** its URL 404s (the leak rule, both halves);
- an unscheduled past date 404s, and `/days/2026-02-31` (passes the route regex, is not a
  real date) 404s rather than raising — **status only; the linen body is story 0004**;
- `/days/<current pick's date>` redirects to `root_path`, **including on a gap day** where
  that date is not today;
- a past day renders that day's artwork, note and date — not the current pick's;
- the list revalidates: same request twice costs a 304, an edited blurb does not, **and an
  edited painting title does not** (the ETag covers both tables);
- the front door revalidates: same request twice costs a 304, **and backfilling a past pick
  does not** (the ETag covers `published.count`);
- the zero-day empty state renders;
- **the one-day list renders its own coda**, and the front door's date is **not** a link;
- with two or more days, the front door's date **is** a link to `/days`;
- prev/next appear on a past day and stop at both ends of the published range;
- **"Next day →" from the day before the current pick targets `/`, not `/days/<date>`**;
- "Today →" is absent when the reader is already on the current pick;
- month headings render for a single month and for two months;
- a row from a previous year carries the year suffix;
- a 104-character title renders without a clamp and picks up `--long`;
- rows are `<li>` inside `<ol>`, and each row's link name carries date + title + artist.

Helper (`test/helpers/application_helper_test.rb`, new):
- attached + `size:` → a variant;
- attached, no size → `url_for` (**regression guard: this is the plate on every screen**);
- not attached → `image_url_800`;
- a blob that cannot be processed → logs once and falls back, no raise.

System (`test/system/days_test.rb`):
- from the front door, two taps reach a past day;
- three missed days are walkable with next/previous without returning to the list, ending
  on the front door;
- zoom works on a past day (same plate — the parity guard);
- a thumbnail that errors leaves its row intact and still navigable;
- at 375 the row keeps its shape and the title does not clamp.

Model (`test/models/daily_pick_test.rb`): `previous_published` / `next_published` boundary
tests next to the existing midnight-boundary ones, including across a gap.

---

## Failure modes

| Codepath | Realistic production failure | Test? | Error handling? | User sees |
|---|---|---|---|---|
| `artwork_src(size:)` | vips cannot read a blob | yes (helper test) | yes — narrow rescue + log | The CDN image, full size. Degraded, not broken |
| `DaysController#index` | A pick's painting was deleted | no — `belongs_to` is required, so it cannot happen | N/A | N/A |
| `DaysController#show` | Date parses by regex but not as a date (`2026-02-31`) | yes | yes — rescue `ArgumentError` → 404 | Stock 404 in this story, linen in 0004 |
| Front door ETag | Backfill leaves the archive link hidden | yes | yes — count in the key | Fixed by this plan |
| List ETag | A re-seed corrects a title, list stays stale | yes | yes — paintings' max in the key | Fixed by this plan |
| `next_published` | Reader on the newest past day when today has no pick | yes (boundary test) | yes — link hidden when nil | No next link, prev still works |
| Thumbnail 404 at the CDN | Museum URL rots | yes (system test) | CSS only — box collapses | An empty framed box; row still reads and navigates |

**Critical gaps (no test AND no handling AND silent): none.**

---

## Parallelization

| Step | Modules touched | Depends on |
|---|---|---|
| 1 — `_day` partial + chrome | `app/views/daily/`, `app/controllers/admin/` | — |
| 2 — `artwork_src(size:)` | `app/helpers/` | — |
| 3-5 — `DaysController` + model | `app/controllers/`, `app/models/`, `config/` | 1 |
| 6 — list view + CSS + DESIGN.md | `app/views/days/`, `app/assets/`, docs | 2, 5 |
| 7 — entry points + ETag | `app/views/daily/`, `app/controllers/daily_controller.rb` | 1, 3 |

**Lane A:** 1 → 3-5 → 7 (sequential, all touch `app/views/daily/` or the controllers).
**Lane B:** 2 (independent — `app/helpers/` only).

Launch A and B in parallel; B merges into A before step 6. Step 6 needs both. Realistically
this is a one-session story and the parallelism is not worth a worktree — noted because the
helper genuinely is independent.

---

## NOT in scope (considered and deferred, with rationale)

- **The linen 404 → story 0004.** Split at eng review: it changes `config.exceptions_app`
  app-wide and improves a page reachable from every route, so it deserves its own revertable
  commit rather than riding inside a feature branch. This story asserts 404 **status**; 0004
  owns the body.
- **Calendar / month grid.** A list answers "what did I miss"; a calendar answers a different
  question and would need the gap rows this plan forbids.
- **Search or filter by artist.** The list is short for months. Revisit with pagination.
- **A "save" affordance on rows.** Favourites is baseline item 4, its own story; a half
  version here would prejudge device-local vs accounts.
- **Sticky month headings.** Rule 5 — a heading that follows you is chrome over the work.
- **Scroll-reveal on rows.** The archive is a gallery walk; this is an index.
- **A desktop thumbnail larger than 112px.** Past that the list becomes variant C, which is
  `/feed` with dates.
- **Pagination.** Trigger written down (`published.count > 90`), not built.
- **Touching picks when their painting changes.** Considered for the ETag; rejected because a
  callback whose only job is cache invalidation makes re-seeding write to `daily_picks` as a
  surprising side effect.
- **Push notifications first.** Codex flagged the sequencing: baseline item 2 (push) is the
  habit driver and this is item 3. Deliberate — push needs a Hotwire Native shell and APNs
  that do not exist yet, and this is the only remaining baseline item that is pure web. Noted
  so the ordering is a choice on the record, not an accident.

## What already exists (reuse, don't reinvent)

| Need | Already in the repo | Reused or rebuilt |
|---|---|---|
| The day page | `daily/show` — renders any `@pick`; the admin preview proves it | Reused, with the chrome extracted |
| The no-leak rule | `DailyPick.published`, Eastern-aware, boundary-tested | Reused verbatim |
| Gap tolerance | `DailyPick.current`'s hold-over, tested in story 0001 | Reused — and it is what forced the current-pick keying |
| Image source rule | `ApplicationHelper#artwork_src` | Extended with `size:`, not duplicated |
| Page shell | `.masthead`, `.page`, `.page--empty`, `.coda`, `.ornament`, `.caps-link` | Reused |
| Artwork treatment | `.plate__img` — `contain`, `--bg-lift`, `--frame-edge` | Reused as the thumbnail's treatment |
| Long titles | `Painting#long_title?` and the `--long` step-down | Reused at list scale |
| Date formats | `Date::DATE_FORMATS[:daily]` / `[:daily_long]` | Reused; year suffix added |
| Index for every new query | `index_daily_picks_on_scheduled_on` (unique) | Reused — covers `published`, ordering, prev/next and the count |
| Image variants | `image_processing` already in the Gemfile | Reused |
| Future pagination | `.sentinel` + the archive's lazy Turbo frame | Deferred to the trigger |
| A precedent to avoid | `admin/daily_picks#index` is already a list of days — Date · Title · muted artist | Deliberately not copied: the public list leads with the picture and a gold title |

## Approved Mockups

| Screen | Mockup | Direction | Notes |
|---|---|---|---|
| `/days` list, 1280 | `~/.gstack/projects/tasteMaker/designs/past-days-list-20260804/variant-a-contents.png` | "Contents page" — text leads, thumbnail is a recognition mark on the right | Built in the real design system with real MIA works, including a 0.27 scroll and a 2.85 screen. Thumbnail grows to 112px per D9 |
| `/days` list, 375 | `~/.gstack/projects/tasteMaker/designs/past-days-list-20260804/variant-a-contents-375.png` | Same row, 72px thumbnail | Measured 126–173px rows, ~5 days per screen |
| Rejected: corridor | `…/variant-b-corridor.png` | Image-led, 132px thumb left | Titles wrap to four lines at 375; density drops to three days |
| Rejected: stacked plates | `…/variant-c-plates.png` | Full plates with dates | ~1.5 days per screen; duplicates `/feed`'s job |

## Implementation Tasks
Synthesized from both reviews. Each task derives from a specific finding.

- [ ] **T1 (P1, human: ~40min / CC: ~10min)** — `daily/_day.html.erb` — extract with the `chrome:` symbol; wire `daily#show`, `days#show`, admin preview
  - Surfaced by: Eng D11 + Codex — a boolean cannot express three contexts; preview was inheriting a live archive link
  - Files: `app/views/daily/_day.html.erb`, `app/views/daily/show.html.erb`, `app/controllers/admin/daily_picks_controller.rb`
  - Verify: existing daily integration + system tests stay green
- [ ] **T2 (P1, human: ~30min / CC: ~10min)** — `artwork_src(painting, size:)` — one helper, narrow logged rescue
  - Surfaced by: Eng D6 — duplicate source rule; bare rescue would hide a broken pipeline
  - Files: `app/helpers/application_helper.rb`, `test/helpers/application_helper_test.rb`
  - Verify: 4 helper tests, including the no-size regression guard
- [ ] **T3 (P1, human: ~40min / CC: ~15min)** — `DaysController` + routes — index, show, current-pick redirect, 404 paths
  - Surfaced by: Eng D9 + Codex — keying on `Date.current` misroutes on gap days
  - Files: `app/controllers/days_controller.rb`, `config/routes.rb`
  - Verify: leak-rule, redirect-on-gap-day and invalid-date tests
- [ ] **T4 (P1, human: ~45min / CC: ~10min)** — `days/index.html.erb` + `.days` CSS — the row exactly as specified
  - Surfaced by: Design Pass 1 + 4 — row anatomy was four nouns and one token reference
  - Files: `app/views/days/index.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: integration tests, then dogfood at 1280/375
- [ ] **T5 (P1, human: ~20min / CC: ~5min)** — no-clamp rule + `--long` step-down at list scale
  - Surfaced by: Design Pass 6 — 104-char titles in the pool, clamp CSS one copy-paste away
  - Files: `app/views/days/index.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: 104-character title test
- [ ] **T6 (P1, human: ~20min / CC: ~5min)** — front-door ETag gains `published.count`
  - Surfaced by: Eng D4 — backfill leaves the archive link invisible behind a 304
  - Files: `app/controllers/daily_controller.rb`
  - Verify: backfill revalidation test
- [ ] **T7 (P1, human: ~20min / CC: ~5min)** — list ETag covers the paintings, computed from the relation
  - Surfaced by: Codex — rows render painting title/artist/image, which the pick key ignores
  - Files: `app/controllers/days_controller.rb`
  - Verify: edited-title revalidation test
- [ ] **T8 (P2, human: ~30min / CC: ~10min)** — entry point — masthead date links to `/days` only when `published.count > 1`
  - Surfaced by: Design D6 — launch day offered a door onto the room you are in
  - Files: `app/views/daily/_day.html.erb`, `app/controllers/daily_controller.rb`
  - Verify: both halves of the gating test
- [ ] **T9 (P2, human: ~40min / CC: ~15min)** — `previous_published` / `next_published` + coda links, with the root-not-redirect rule
  - Surfaced by: Design D8 + Eng D5 — nine taps to catch up; last step hit a 301
  - Files: `app/models/daily_pick.rb`, `app/views/daily/_day.html.erb`
  - Verify: boundary tests both ends, gap-day test, system test walking three days
- [ ] **T10 (P2, human: ~30min / CC: ~10min)** — accessibility — `<ol>`/`<li>`, full link names, `<time datetime>`, `alt=""`, `<h2>` months
  - Surfaced by: Design D11 — the plan contained no a11y specification
  - Files: `app/views/days/index.html.erb`
  - Verify: link-name and list-structure tests
- [ ] **T11 (P2, human: ~20min / CC: ~5min)** — month grouping in `DaysController#index`, one-month and two-month tests
  - Surfaced by: Eng D7 — grouping had no stated home; ERB is the least testable one
  - Files: `app/controllers/days_controller.rb`, `app/views/days/index.html.erb`
  - Verify: single-month and multi-month rendering tests
- [ ] **T12 (P2, human: ~20min / CC: ~5min)** — one-day and zero-day states with their codas
  - Surfaced by: Design Pass 2 — five of six states unspecified
  - Files: `app/views/days/index.html.erb`
  - Verify: one-day coda test, empty-state test
- [ ] **T13 (P2, human: ~15min / CC: ~5min)** — `DESIGN.md`: the contents-list component, the colour inversion, the card ban
  - Surfaced by: Design D10 + both outside voices — an undocumented inversion drifts
  - Files: `DESIGN.md`
  - Verify: `bin/rails test test/system/design_test.rb`
- [ ] **T14 (P3, human: ~15min / CC: ~5min)** — year suffix on dates from a previous year
  - Surfaced by: Design Pass 4 — neither date format carries a year
  - Files: `app/helpers/application_helper.rb`, `app/views/days/index.html.erb`
  - Verify: freeze-time test across a year boundary
- [ ] **T15 (P3, human: ~15min / CC: ~5min)** — seed stress cases: a 100+ char title, a sub-0.4 aspect ratio, and a gap day
  - Surfaced by: Design Pass 6 + Eng D9 — the stress cases exist in the pool and the gap day is the riskiest state
  - Files: `db/seeds.rb`
  - Verify: manual, at 375

## Deviations (added during build)

- 2026-08-04: **No libvips on this machine, so variants cannot be generated at all.**
  `config/application.rb:42` already says so for the analyzers; the plan missed the same
  fact applying to `resize_to_limit`. `ActiveStorage.variant_transformer` is `nil` here,
  and asking for a variant anyway does **not** raise in the helper — it raises inside
  Active Storage's redirect controller, so every thumbnail 500s and the narrow rescue the
  eng review specified never sees it. Dogfooding caught it; tests did not, because the
  tests only build the variant and never resolve it. Fixed with a capability check
  (`resizing_available?`) that falls back to the whole image, so the archive works with or
  without an image processor on the box. Production will have one (the Rails 8 Dockerfile
  installs libvips), and the page is correct either way.
- 2026-08-04: `fresh_when([record, count])` treats the array as records and calls
  `updated_at` on the Integer. The front door uses `fresh_when(etag:, last_modified:)`
  instead.
- 2026-08-04: `days#show` renders explicitly, and `fresh_when` sends its own 304, so the
  two together raise `DoubleRenderError` on a revalidated request. Switched to
  `render ... if stale?(...)`. The system test caught it; the integration test had not
  been sending `If-None-Match` on a day page, so a test for that was added.
- 2026-08-04: the paintings' `maximum(:updated_at)` goes into the ETag as `.to_f`.
  Interpolating a `Time` renders it at second precision, so a title edited in the same
  second as the previous request produced an identical key and a stale 304 — which the
  test for exactly that behaviour caught.
- 2026-08-04: **year suffix on rows dropped.** The month heading reads "August 2026", so a
  per-row year was the same fact twice. One place shows the year. `day_label` was removed
  with it; the row uses `to_fs(:daily)` directly.
- 2026-08-04: `minitest/mock` is not available under Minitest 6, so the helper test swaps
  `ActiveStorage.variant_transformer` directly and restores it in an `ensure`.
- 2026-08-04: noted, not fixed — a **helper-only** change does not bust either page's ETag,
  because Rails' template digest covers templates and partials but not helpers. Harmless
  in production (deploys move the importmap, and `stale_when_importmap_changes` is already
  on) but it will confuse anyone dogfooding a helper edit locally, as it did here.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 2 (design + eng outside voices) | issues absorbed | design: 8 findings, 0 hard rejections; eng: 11 findings — 3 absorbed as new decisions, 4 were stale-plan artifacts, 4 noted |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAN | 9 issues, 0 critical gaps, scope reduced (404 → story 0004) |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | score: 5/10 → 9/10, 7 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** the eng outside voice caught the load-bearing error in this plan — `DailyPick.current`
holds the previous pick over on a gap day, so every rule keyed on `Date.current` misroutes
exactly when the archive matters most. It also caught the list ETag ignoring the paintings its
rows render, and corroborated the `front_door:` boolean being too crude for three callers. Four
of its remaining points were the plan lagging decisions made minutes earlier in the same session.

**CROSS-MODEL:** design phase — Codex and the Claude subagent converged on the masthead date as
the entry point and diverged on whether the picture must lead; the subagent's measurements
(titles to 104 chars, aspect ratios 0.27–2.85) settled the row geometry. Eng phase — Codex found
the gap-day hole that the first-party review missed entirely, and both agreed on the chrome
modes. One Codex point was rejected with a written reason: sequencing the archive before push
is deliberate, because push needs a native shell that does not exist.

**VERDICT:** DESIGN + ENG CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
