# 0007 — The cookie the front door should not be handing out
Date: 2026-08-04
Lane: Express (same-day, reversible)
Status: Shipped 2026-08-05 — split out of story 0006 at eng review (2026-08-04); built, bin/ci green, pushed

## Who
Every reader, none of whom will ever see this. Also the next person to put a cache or a CDN
in front of this app, which on current configuration is the first Kamal deploy.

## Problem
Measured on this checkout, dev env, 2026-08-04:

```
/      status=200  cc="public, no-cache"  set-cookie="_taste_maker_session=…; path=/; httponly; samesite=lax"
/days  status=200  cc="public, no-cache"  set-cookie="_taste_maker_session=…; path=/; httponly; samesite=lax"
/feed  status=200  cc="max-age=0, private, must-revalidate"  set-cookie="_taste_maker_session=…"
```

Every public page sets a session cookie. `csrf_meta_tags` in
`app/views/layouts/application.html.erb:12` calls `form_authenticity_token`, which writes
`session[:_csrf_token]`, which forces the cookie. Stories 0001 and 0003 marked `/` and
`/days` `public` on purpose — a shared cache is allowed to store those responses and replay
them, **including the stored `Set-Cookie` and the masked CSRF token baked into the same
body.** Those two travel together, so a replay hands visitor B a working impersonation of
visitor A.

It has not bitten because nothing is deployed. That ends at the first deploy:

```
Dockerfile:77   CMD ["./bin/thrust", "./bin/rails", "server"]
thruster 0.1.23 README:  "Basic HTTP caching"  ·  CACHE_SIZE default 64MB  ·  no config file
```

Production starts behind a shared HTTP cache that is on by default and has no off switch in
this repo's config. BET.md wants the app in the App Store by Aug 14.

## Story
As the person deploying this, I want no public page to hand out a session cookie, so that
the cache sitting in front of production cannot serve one reader's identity to another.

## Intake
- Evidence: the measurement above, plus `Dockerfile:77` and the Thruster README's default
  64MB cache. Not a hypothesis — both halves are read off this checkout.
- Success signal (prediction), checkable the day it lands: `curl -sI` against `/`, `/days`
  and `/days/:date` returns **no `Set-Cookie`** and still returns `Cache-Control: public,
  no-cache` with a working ETag. The curator's desk still deletes a queued day.
- Verified before writing this: stubbing `csrf_meta_tags` to `nil` and re-requesting all
  three pages returns `set_cookie=NONE` on each, with cache headers unchanged. It is the
  only session writer on the public path — `grep` finds no `session[` or `flash` outside
  `app/controllers/admin/`.
- In baseline? No. It is a defect on already-shipped pages. Split out of story 0006 at eng
  review for the same reason story 0004 was split out of 0003: an app-wide change belongs in
  its own revertable commit, and this one is a security fix that should not wait behind a
  two-day feature.

## Acceptance
- `/`, `/days` and `/days/:date` return no `Set-Cookie`, and keep `public, no-cache` + ETag.
- The curator's desk keeps working, including the delete link, which is
  `data: { turbo_method: :delete }` at `app/views/admin/daily_picks/index.html.erb:64` and
  therefore needs `meta[name=csrf-token]` present in the admin pages it runs on.
- The curator's preview still renders the **reader's** page, not an admin-chromed one.
- No visual change on any screen. `test/system/design_test.rb` stays green.

## Out of scope
- Anything to do with favorites. This story has no consumer and needs none; it stands on the
  measurement above. Story 0006 depends on it and ships after.
- Changing `Cache-Control` on any page. The headers are correct; the cookie is the defect.
- Kamal, Thruster tuning, or any deploy work.
