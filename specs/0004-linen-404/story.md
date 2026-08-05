# 0004 — The page that isn't there
Date: 2026-08-04
Lane: Express (same-day, reversible)
Status: Shipped 2026-08-05 — split out of story 0003 at eng review (2026-08-04); built, bin/ci green

## Who
Anybody who follows a link to a day that no longer exists, types a date by hand, or
bookmarks `/days/2026-08-04` before it has arrived. Also every future reader who hits any
wrong URL in the product, because this page is not really about days.

## Problem
`public/404.html` is the stock Rails page: white background, system font stack, "The page
you were looking for doesn't exist." It is the only screen in the product that is not on
linen paper, and `decisions/0003-one-skin.md` says there is exactly one accepted exception
to that (the full-screen view), which this is not.

Until story 0003 nothing deliberately routed anyone there. Now something does: `/days/:date`
404s for a queued day, an unscheduled day, a removed day, and a hand-typed date — and the
URL shape is guessable enough that people will type them. A shared link to a day that got
pulled lands a stranger on a page that looks like the site is broken.

## Story
As somebody who followed a dead link into Tastemaker, I want the page that tells me so to
look like the rest of the product, so that a missing day reads as a missing day rather
than as a broken site.

## Intake
- Evidence: `DESIGN.md` rule 1 ("One skin") and `test/system/design_test.rb`, which fails
  if any screen drifts from the linen palette — the 404 escapes that test only because it
  is a static file outside the asset pipeline. Story 0003 is what creates the traffic.
- Success signal (prediction): after ship, every 404 in the app renders on linen with the
  ornament and a way back, and `curl -s -o /dev/null -w "%{http_code}"` on an unscheduled
  date still returns 404 — the styling changes, the status code does not. Checkable by hand
  the day it lands.
- In baseline? No. It is a quality bar (`CLAUDE.md` Better bucket item 4, "calm") applied
  to a screen the product already has, not a new capability. Split from 0003 because
  `config.exceptions_app` is an app-wide change and deserves its own revertable commit.

## Acceptance
- A 404 from any route renders on linen: `.page--empty` + `.coda` — ornament, a line in the
  product's voice, and a `.caps-link` back to somewhere useful.
- The status code stays 404. This is a styling change, not a redirect.
- The 500 page gets the same treatment, or it is explicitly left alone with a written reason.
- `test/system/design_test.rb` is extended to cover the 404, so the one-skin rule is
  enforced on it like every other screen.
- Copy is contextual where it is cheap: a date that has no artwork says so
  ("There was no artwork on that day.") rather than the generic line.

## Out of scope
- Custom pages for every status code. 404 and 500 are the two anyone sees.
- A search box or suggestions on the 404. The product has three screens; a link back is enough.
- Error tracking wiring. That is a session-gate item (gate 6) with its own scope.
