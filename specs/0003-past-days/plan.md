# 0003 — Implementation plan
Status: Draft — /plan-design-review required before step 1 (this adds a screen with a
list idiom the design system does not have yet), then /plan-eng-review.

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

**Chrome fork.** `daily/show` currently hard-codes "Artwork of the Day" and "See you
tomorrow." Neither is true on a past day. Extract the body into `daily/_day.html.erb`
with a `front_door:` local:

| | front door (`/`) | a past day (`/days/:date`) |
|---|---|---|
| masthead label | Artwork of the Day | From the archive |
| coda line | See you tomorrow. | (none) |
| coda links | Past days → · Wander the full gallery → | ← All days · Today → |

The admin preview keeps rendering `daily/show` with `front_door: true`, which is what a
curator is previewing.

**Thumbnails.** `image_processing` is already in the Gemfile, so locally attached artwork
gets an Active Storage variant (`resize_to_limit: [400, 400]`) for the list; a painting
still on the CDN fallback uses `image_url_800` at CSS size. One helper,
`artwork_thumb(painting)`, next to `artwork_src`. Thumbnails are `object-fit: contain`
like every other artwork on the site — `DESIGN.md` rule 2 holds here too, a list is not
a licence to crop.

**Caching.** Same shape as the daily page: `fresh_when` + `public, no-cache`, so a blurb
edit shows immediately and an unchanged list costs a 304. The index ETag includes
`Date.current` so the list rolls over at Eastern midnight when a queued day becomes
published without any record changing.

**No pagination.** One pick per day means the list crosses 90 entries in month four.
Trigger written down rather than built: **when `DailyPick.published.count > 90`, paginate
with the same lazy Turbo frame the archive uses.** Until then a single query and a single
render, `with_artwork` so images are not an N+1.

## Open questions for /plan-design-review

1. **List row vs grid.** Proposal: one row per day — date on the left in the small-caps
   metadata style, contained thumbnail, title, artist. Rows read like a table of contents,
   which is the job. A grid reads like a gallery, which `/feed` already is.
2. **Is today in the list?** Proposal: yes, first, labelled "Today", linking to `/`.
   Leaving it out makes the newest entry look stale; putting it in makes the list complete.
3. **Month headings?** Proposal: yes, a hairline rule with the month name once entries
   cross into a second month. Costs nothing, and it is the only structure a long list gets.
4. **Where the entry point lives.** Proposal: a second `.caps-link` in the daily page's
   coda ("Past days →"), above the existing gallery link. The alternative — a link in the
   masthead — puts navigation chrome next to the artwork, which rule 5 pushes against.
5. **Empty state copy.** Proposal: reuse the coda pattern — ornament + "The days will
   collect here." + a link to the gallery.
6. **Does a past day get a "Today →" link in its coda?** Proposal: yes. Somebody who
   walks back three days should be one tap from the ritual.

## Steps

1. Extract `daily/_day.html.erb` from `daily/show`, with `front_door:` local; point
   `daily/show` and the admin preview at it. Behaviour unchanged, suite green.
2. `DaysController#show` + route + 404 paths. Tests for the leak rule first.
3. `artwork_thumb` helper + variant fallback.
4. `days/index.html.erb` + the list CSS as agreed at design review; add the component to
   `DESIGN.md` and re-render the Claude Design card for it.
5. Entry points: the daily coda link, and the past-day coda links.
6. `bin/ci` green, then dogfood at 1280 and 375 with at least three published days seeded.

## Tests

Integration (`test/integration/days_test.rb`):
- the list shows published days newest first, and today is in it;
- a queued future day is absent from the list **and** its URL 404s (the leak rule, both
  halves);
- a malformed date and an unscheduled past date both 404;
- a past day renders that day's artwork, that day's note, and that day's date — not
  today's;
- the list revalidates: same request twice costs a 304, an edited blurb does not;
- the empty state renders when nothing is published.

System (`test/system/days_test.rb`):
- from the front door, two taps reach a past day;
- zoom works on a past day (it is the same plate, so this is the parity guard);
- the back link returns to the list.

Model: `DailyPick.published` already carries story 0001's midnight-boundary coverage;
this story adds no new date rule, so no new model test. If step 2 needs one, it goes in
`test/models/daily_pick_test.rb` next to the existing boundary tests.

## Risks

- **The screen is nearly empty at launch.** One published day today. Mitigation is the
  empty/thin state being deliberate rather than an afterthought — it is question 5 at
  design review, not a detail left to implementation.
- **Variant generation on first request.** The first visit to the list processes N
  thumbnails through vips inline. With a handful of days this is milliseconds; if the
  list ever feels slow before pagination arrives, the fix is a variant-warming job, not
  a bigger page. Named, not built.
- **Two templates drifting.** The front door and a past day share `_day.html.erb`, so
  they cannot; the guard is the existing system test on the daily page plus the new zoom
  parity test on a past day.

## Deviations (added during build)
- <date>: <what changed vs plan, why>
