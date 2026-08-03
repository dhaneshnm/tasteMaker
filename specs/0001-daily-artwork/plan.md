# 0001 — Implementation plan
Status: Draft

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

Model: `belongs_to :painting`; validations mirror the constraints;
`DailyPick.current` → pick with latest `scheduled_on <= Date.current` (fallback for
unscheduled days comes free: yesterday's pick stays up).

## "Today" rule (Better bar 5)
Day rolls at midnight in one app-wide timezone: `config.time_zone = "America/New_York"`
(**confirm at review**). No per-visitor timezone logic — that's infrastructure for later;
revisit only if reviews ever complain. No tomorrow-leak: `current` never selects
`scheduled_on > Date.current`.

## Routes
- `root "daily#show"` (was `paintings#index`)
- `get "feed" => "paintings#index"` — feed reachable, frozen; fix its lazy-frame
  next-page URLs if they assume root
- `namespace :admin { resources :daily_picks, except: :show }`

## Screens
1. **Today** (`daily#show`): artwork image (capped height so blurb's first lines share
   the viewport — Better bar 2), title / artist / meta line, blurb, quiet footer link to
   the feed. Empty DB edge: friendly placeholder (pre-launch only). HTTP cache headers to
   end of day.
2. **Admin queue** (`admin/daily_picks`): `http_basic_authenticate_with`, password in
   Rails credentials. Index = upcoming + past picks; form = painting select (unpicked
   paintings, newest first), date field (defaults to first unscheduled date), blurb
   textarea. Plain scaffold-grade UI — the curator is the only user.

## Steps
1. Migration + `DailyPick` model + fixtures + model tests.
2. `DailyController#show` + view + integration/system tests (today shown; fallback day
   shows latest pick; art and blurb co-visible assertion).
3. Route move: root swap, `/feed`, fix feed frame URLs; test feed still paginates.
4. Admin controller + views + auth + tests (401 without credentials; create/edit flows).
5. README root-URL note; `bin/ci` green.

## Tests
- Model: constraint pair (unique date, unique painting), blurb presence, `current`
  selection incl. no-future-leak case.
- Integration: root renders today's pick; unscheduled day falls back; feed at `/feed`
  paginates; admin requires auth; admin create schedules a day.
- System (Capybara): visitor opens root, sees image + blurb together with zero clicks.

## Out (named so they don't creep)
- Solid Queue / publish job — nothing to run until push (story for feature #2).
- Archive UI (#3), favorites (#4), widget, per-visitor timezones, page caching beyond
  HTTP headers, museum-API ingestion.

## Estimate
~1 day. Fits Full lane.

## Deviations (added during build)
- (none yet)
