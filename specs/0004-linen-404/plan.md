# 0004 — Implementation plan
Status: Built 2026-08-05. UI-light: `/plan-design-review` skipped deliberately
(no new component; it reuses `.page--empty` + `.coda` verbatim). `/plan-eng-review` not run —
Express lane, one controller, one template, no data model.

## Approach

`config.exceptions_app = routes` sends rescued exceptions back through the router, so a 404
renders as a normal request with the normal layout. Everything else follows from that.

```
  request → 404 raised → ActionDispatch::ShowExceptions
                             │
                     exceptions_app = routes
                             │
                    GET /404  →  ErrorsController#not_found
                             │
                    layouts/application  →  linen, one skin
```

Three files:

| File | Change |
|---|---|
| `config/application.rb` | `config.exceptions_app = routes` |
| `config/routes.rb` | `match "/404" => "errors#not_found", via: :all` (and `/500`, `/422`) |
| `app/controllers/errors_controller.rb` | new — renders the right template with the right status |
| `app/views/errors/not_found.html.erb` | new — `.page--empty` + `.coda` |

### Status codes are the whole point

`render ..., status: 404`. The story says it plainly: this is a styling change, not a
redirect. `curl -s -o /dev/null -w "%{http_code}"` on an unscheduled date must still say
404 after this ships, and there is a test for exactly that.

### Contextual copy, cheaply

`ActionDispatch::ExceptionWrapper` puts the original exception on
`request.env["action_dispatch.exception"]`. A day that does not exist raises
`ActiveRecord::RecordNotFound` from `DaysController#show`; a typo'd URL raises
`ActionController::RoutingError`. That is enough to tell "no artwork on that day" from
"that page does not exist" without inspecting the path:

```ruby
def not_found
  @message = case request.env["action_dispatch.exception"]
             when ActiveRecord::RecordNotFound then "There was no artwork on that day."
             else                                   "That page does not exist."
             end
  render status: :not_found
end
```

The story asks for the contextual line "where it is cheap". This is cheap. Anything that
parses the path to guess intent is not, and is out of scope.

### The 500 page — left alone, with the reason written down

The story allows either. Leaving it: a 500 means the app is already broken, and rendering
it through the same layout means the error page depends on the asset pipeline, the fonts,
`content_for`, and every partial the layout touches. If the failure that caused the 500 is
in any of those, Rails falls back to a blank page and the reader gets nothing. The static
`public/500.html` cannot fail that way. Keeping it is not laziness; it is the one page that
should not share the product's machinery.

`public/404.html` is deleted — the router owns 404 now, and a stale copy on disk is a
second answer to the same question. `422` routes to the same action as 404 (a rejected
request is not a page), while `400` and `406-unsupported-browser` keep their static files:
both fire before or outside normal request handling.

## Steps

1. `config.exceptions_app = routes`; routes for `/404`, `/422`, `/500`.
2. `ErrorsController` + `errors/not_found.html.erb`.
3. Delete `public/404.html`.
4. Extend `test/system/design_test.rb` — the 404 is a screen, so the one-skin test covers it.
5. `bin/ci` green, then curl a bad URL and a bad date in a real server.

## Tests

`test/integration/errors_test.rb` (new):
- an unscheduled past date returns **404**, not a redirect, and renders the linen page;
- a malformed date (`/days/2026-02-31` — passes the route regex, is not a real date) 404s;
- a wholly unrouted path (`/nope`) 404s and renders the same page;
- a queued future day 404s (the leak rule from story 0003, now through the new page);
- the RecordNotFound case says "no artwork on that day" and the routing case does not;
- the page carries a link back, and **sets no `Set-Cookie`** — it renders the public layout,
  so story 0007's rule applies to it too.

`test/system/design_test.rb` (extend): the 404 renders on the same paper, in the same type,
as the front door. This is the story's stated forcing function — the 404 escaped the
one-skin test only because it was a static file outside the pipeline.

## Failure modes

| Codepath | Realistic failure | Test? | Handling? | Reader sees |
|---|---|---|---|---|
| `exceptions_app` | A raise inside the error template itself → blank page | no | Rails falls back to static `public/500.html` | The static 500 |
| Status code | A refactor turns the render into a redirect | **yes** | — | 404 preserved |
| Public-layout rule | Error page emits a session cookie | **yes** | story 0007's layout | No cookie |
| 500 | Left static, deliberately | n/a | n/a | The static page |

**Critical gaps: none.**

## NOT in scope

- **Styling the 500.** Reason written above.
- **A search box or suggestions.** Three screens; a link back is enough (story).
- **Per-status pages beyond 404/422.** Nobody sees the others.
- **Error tracking.** Session gate 6, its own scope.

## What already exists

| Need | Already in the repo | Reused |
|---|---|---|
| Empty-state shell | `.page--empty` + `.coda` + `.ornament` + `.caps-link` | Verbatim — no new CSS |
| Copy voice | `daily/empty.html.erb`'s "The first artwork arrives soon." | Same register |
| One-skin enforcement | `test/system/design_test.rb` | Extended, not replaced |
| Public-layout rule | story 0007's `layouts/application` | Inherited automatically |

## Deviations (added during build)

- _(none yet)_
