# 0021 — The mock door

Date: 2026-08-19
Lane: Express (same-day, reversible)
Status: Draft

## Who

**The curator (Dhanesh)** — building and QA-ing every story from 0015 onward that lives
behind `require_reader`: the corner (0017), the listing/collection claim (0016), handoff
(0017 Release 2), favorites. Every one of those screens is currently unreachable in a local
`rails s` session.

## Problem

**Local dev has no way to sign in, so every authenticated screen is untestable by hand.**

`config/initializers/omniauth.rb` configures both providers from Rails credentials or ENV,
falling back to blank strings when neither is set — a fresh checkout has neither. Even with
real Google credentials filled in, Apple cannot be exercised locally at all:
`sessions_controller.rb:28-36` and `omniauth.rb`'s own header note both say the Apple
callback is a cross-site POST verified only on the deployed domain.

The suite already solved this for automated tests — `test/test_helper.rb:16-17` sets
`OmniAuth.config.test_mode = true` for the whole run, and `mock_auth` (test_helper.rb:82-88)
writes a fake `AuthHash` per test. Nothing equivalent exists for a human clicking around a
local server. Today that means:

- `/corner`'s `:account` and `:device` states, `/collection`, and the handoff claim flow
  (`specs/0017-your-corner`) can only be eyeballed by deploying first.
- `/qa` runs against production or not at all for anything past the sign-in wall.
- A regression in `require_reader`, `Favorite.claim!`, or the corner's four-state branch
  is invisible until it is live.

## Story

As the curator, I want to sign in as a fake reader on my local server, so I can see and
click through every wall-gated screen without a deploy or real OAuth credentials.

## Intake

- **Problem:** no authenticated screen is reachable in local dev without real, live
  Google/Apple credentials — and Apple never works locally regardless.
- **Evidence:** `config/initializers/omniauth.rb` (credentials/ENV fallback to blank);
  `app/controllers/sessions_controller.rb:28-36` (Apple verified on deployed domain only);
  `test/test_helper.rb:16-88` (the mock pattern already proven for the automated suite,
  reused here for a human).
- **Success signal (prediction, falsifiable, time-bound):** by **Aug 20, 2026**, hitting
  `GET /dev/sign_in` on a local `rails s`, picking a provider and submitting, lands
  signed in at `/days` — real `session[:user_id]`, real `SessionsController#create`,
  zero network calls to `accounts.google.com` or `appleid.apple.com`. Same route returns
  404 when `Rails.env.development?` is false, checked by a test that boots the router in
  `test` env. Falsified if the route is reachable outside development, or if it writes a
  session any other way than the real `SessionsController#create`/`#handoff` path.
- **In baseline?** No — dev tooling, not a product surface. Exception evidence: every
  story since 0015 has shipped an authenticated screen with no way to click through it
  locally; the cost is paid every session doing manual QA on `/corner`, `/collection`, or
  the handoff flow.

## Out of scope

- Fixing real Apple sign-in locally — stays impossible, unchanged, documented already.
- Any change to `SessionsController`, `User`, or the real OmniAuth provider config.
- A CI/test-suite change — `test_helper.rb` already mocks auth for Minitest; this is the
  human-driven equivalent for a browser.
- Making this reachable in `staging`/`production` under any flag — development only, no
  toggle, no exception.
