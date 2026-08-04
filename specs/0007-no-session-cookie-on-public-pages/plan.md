# 0007 — Implementation plan
Status: Draft — written at story 0006's eng review (2026-08-04). Ships **before** 0006.
UI-light: `/plan-design-review` skipped deliberately, no visual change on any screen.

## Approach

One idea: the public layout stops emitting a CSRF token, because no public page has a form.
The curator's desk does have forms, so it gets its own layout that keeps the token.

```
                       BEFORE                                   AFTER
  layouts/application.html.erb                    layouts/_head.html.erb   ← shared
    ├─ csrf_meta_tags        ← writes session       ├─ title, meta, fonts, stylesheet,
    ├─ head, fonts, importmap                       │  importmap, yield :head
    └─ used by EVERY page                           │
                                                    ├─ layouts/application.html.erb
  /       public, no-cache + Set-Cookie   ✗         │    renders _head, NO csrf_meta_tags
  /days   public, no-cache + Set-Cookie   ✗         │    → /, /days, /days/:date, /feed
  /feed   private          + Set-Cookie             │
  /admin  private          + Set-Cookie   (fine)    └─ layouts/admin.html.erb
                                                         renders _head + csrf_meta_tags
                                                         → Admin::BaseController
```

`form_with` embeds its own hidden `authenticity_token`, so the admin edit form never needed
the meta tag. The delete link does: `app/views/admin/daily_picks/index.html.erb:64` uses
`data: { turbo_method: :delete }`, and Turbo reads `meta[name=csrf-token]` for that.

### Where the layout goes

`layout "admin"` on **`Admin::BaseController`**, not on `Admin::DailyPicksController`.
`Admin::BaseController` already exists (`app/controllers/admin/base_controller.rb`) and
already owns the HTTP basic auth for the whole namespace. Putting the layout on the leaf
controller means the next admin controller silently inherits the public layout and
reintroduces this exact defect.

### The preview keeps the reader's layout

`Admin::DailyPicksController#preview` (`app/controllers/admin/daily_picks_controller.rb:52`)
does `render template: "daily/show"` with no `layout:`. Once the namespace has its own
layout, that preview renders the reader's page inside **admin** chrome — which quietly
breaks the thing preview exists for. It becomes:

```ruby
render template: "daily/show", layout: "application"
```

Caught by the outside voice at 0006's eng review; neither first-party review saw it.

## Verified before planning

| Claim | How it was checked | Result |
|---|---|---|
| `csrf_meta_tags` is the session writer | Stubbed it to `nil`, re-requested `/`, `/days`, `/feed` | `set_cookie=NONE` on all three, cache headers unchanged |
| Nothing else writes the session | `grep -rn "session\[\|flash\[\|flash\."` over `app/` minus `admin/` | no hits |
| Production has a shared cache | `Dockerfile:77`, thruster 0.1.23 README | `bin/thrust`, 64MB cache, on by default |
| The delete link needs the meta tag | `app/views/admin/daily_picks/index.html.erb:64` | `data: { turbo_method: :delete }` |
| Admin base controller exists | `app/controllers/admin/base_controller.rb` | yes, owns auth for the namespace |

## Steps

1. Extract `layouts/_head.html.erb` — everything both layouts share. Render it from
   `application.html.erb`. No behaviour change yet; suite green.
2. Add `layouts/admin.html.erb` = `_head` + `csrf_meta_tags`. Put `layout "admin"` on
   `Admin::BaseController`.
3. `preview` renders with `layout: "application"`.
4. Remove `csrf_meta_tags` from `application.html.erb`.
5. `bin/ci` green, then curl the three public routes and confirm no `Set-Cookie`.

## Tests

`test/integration/public_cache_headers_test.rb` (new):
- `/`, `/days`, `/days/:date` return **no `Set-Cookie`**;
- the same three still return `Cache-Control: public, no-cache` and a usable ETag — a
  repeat request with `If-None-Match` still 304s;
- `/feed` also emits no `Set-Cookie` (it was never `public`, but it was emitting one).

`test/integration/admin/daily_picks_test.rb` (extend):
- **the admin layout renders `meta[name=csrf-token]`** — the delete link is JS-driven, so
  an integration `DELETE` proves nothing about what actually broke. Assert the tag exists;
- the preview page renders the **reader's** masthead, not admin chrome.

`test/system/admin_test.rb` (new, one test): clicking the queue's delete link in a real
browser actually deletes the day. This is the only test that exercises the meta tag the way
Turbo does. Without it, step 4 can silently break the curator's desk.

`test/system/design_test.rb`: unchanged, must stay green — proves the layout split moved no
pixels.

## Failure modes

| Codepath | Realistic failure | Test? | Handling? | User sees |
|---|---|---|---|---|
| Public page + Thruster cache | Stored `public` response replays `Set-Cookie` + matching CSRF token | yes — the no-`Set-Cookie` assertions | yes — this story | Nothing. That is the point |
| Admin delete | Meta tag gone, Turbo's `turbo_method: :delete` silently no-ops | yes — system test | yes — admin layout keeps the tag | Delete works |
| Future admin controller | Inherits the public layout, loses the tag | partially — the meta-tag assertion is on the namespace's base | yes — layout on `Admin::BaseController` | Works |
| Preview | Renders in admin chrome, stops being the reader's page | yes | yes — explicit `layout: "application"` | The reader's page |

**Critical gaps: none.**

## NOT in scope

- **Favorites.** Story 0006, ships after this.
- **Changing any `Cache-Control` value.** The headers are right.
- **A CSP or any other header work.** `config/initializers/content_security_policy.rb` is
  entirely commented out. Real, and not this story.
- **Kamal / Thruster configuration.** First deploy owns it.

## What already exists

| Need | Already in the repo | Reused or rebuilt |
|---|---|---|
| Admin auth boundary | `Admin::BaseController` with HTTP basic | Reused — the layout hangs off the same class |
| Preview's reader-page intent | `chrome: :preview`, story 0003 | Reused; this story keeps it honest through the layout change |
| Visual regression guard | `test/system/design_test.rb` | Reused as the proof that nothing moved |
| Shared head markup | `layouts/application.html.erb` | Extracted, not duplicated |

## Deviations (added during build)

- 2026-08-04: **every test in this story had to run inside `with_forgery_protection`, or all
  of them passed against the unfixed code.** `config/environments/test.rb:29` disables
  forgery protection, and `csrf_meta_tags` returns nil without ever calling
  `form_authenticity_token` when it is off — so in the test environment the *old* layout
  also emitted no `Set-Cookie` and rendered no meta tag. The helper went on
  `ActiveSupport::TestCase` so the system test could use it too.
- 2026-08-04: verified the admin system test is not vacuous by deleting `csrf_meta_tags`
  from the admin layout and re-running it. It fails. Restored.
- 2026-08-04: `assert_select "meta[name=?][content=?]", "csrf-token", /.+/` does not work —
  `assert_select` does not substitute a Regexp into an attribute selector. Asserts on the
  parsed element's `content` instead.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | **NOT RUN — required** | — |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | skipped — no visual change | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**VERDICT:** Split out of story 0006's eng review with three findings already folded (layout
on `Admin::BaseController`, preview layout, meta-tag assertion). Eng review required before
implementation.

NO UNRESOLVED DECISIONS
