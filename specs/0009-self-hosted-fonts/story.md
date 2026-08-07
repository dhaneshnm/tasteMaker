# 0009 — The typefaces come from us

Date: 2026-08-06
Lane: Express (same-day, reversible)
Status: Spec written 2026-08-06 — not started. **Ships before story 0008.**

## Who

**Maya** — Daily Ritual Learner, persona 1 (`specs/personas.md`). 33, pediatric nurse in
Columbus. She opens the app on her morning tea and on hospital wifi, which is not good
wifi. She has 1–3 minutes and she is not going to wait.

**Jordan** — Collector, persona 2. Three years of curating on a cracked-screen iPhone.
Old hardware, and whatever cell signal Portland gives them.

Secondary: **the curator (Dhanesh)**, who has to fill in App Store privacy labels before
the first external user (session gate 6) and would have to disclose this if it stayed.

## Problem

Every cold load of Tastemaker reaches out to Google before it can render a word in the
right typeface.

```
app/views/layouts/_head.html.erb:27   <link rel="preconnect" href="https://fonts.googleapis.com">
app/views/layouts/_head.html.erb:28   <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
app/views/layouts/_head.html.erb:29   <link href="https://fonts.googleapis.com/css2?family=Fraunces…&Newsreader…">
```

That is **two extra hosts, two DNS lookups, and two TLS handshakes** on the critical
rendering path, before a render-blocking stylesheet that itself then fetches font files
from a third host. Three things follow, and none of them is theoretical:

1. **It contradicts a stated quality bar.** `CLAUDE.md`, Better bucket item 3: *"Fast:
   images cached locally, no stutter, instant open."* The images are cached locally. The
   typefaces — which are the product's entire visual identity, two families and nothing
   else (`DESIGN.md`) — are not.

2. **Offline, the product loses its face.** `--serif-display` falls back to Iowan Old
   Style then Georgia; `--serif-body` falls back to Georgia. The linen page survives, the
   voice does not. Story 0008 makes this worse, not better: the native shell's error
   screen exists precisely for the no-network case, and a native app is judged on launch
   speed in a way a web page is not.

3. **Every launch sends a reader's IP address to a third party.** Session gate 6 requires
   accurate App Store privacy labels before the first external user. A font CDN request is
   a disclosable third-party contact, on every cold load, made by an app whose pitch is
   *calm, no ads, nothing between you and the art.*

Nothing blocks the fix. `config/initializers/content_security_policy.rb` is entirely
commented out, so no policy has to be renegotiated — and self-hosting is what makes a
strict `font-src 'self'` policy possible later.

## Story

As Maya on hospital wifi, I want the app to render in its own typefaces without asking
another company for them first, so that my three minutes are not spent on someone else's
handshake.

## Intake

- **Problem:** the product's two typefaces load from `fonts.googleapis.com` /
  `fonts.gstatic.com`, adding two hosts to the critical path, breaking the typography
  offline, and contacting a third party on every launch.
- **Evidence:**
  - `CLAUDE.md` Better bucket item 3 — "Fast … instant open" — is a stated quality bar
    this violates.
  - `app/views/layouts/_head.html.erb:27–29`, measured on this checkout 2026-08-06.
  - Story 0008 design review, 2026-08-06, decision 6: pulled out of that plan's
    out-of-scope table and put ahead of it.
  - `CLAUDE.md` session gate 6 — accurate App Store privacy labels before first external
    user.
  - Both families are **SIL Open Font License**, so self-hosting is licensed, not a
    workaround.
- **Success-signal prediction (falsifiable, time-bound):** by **Aug 7, 2026**, a cold load
  of `/` makes **zero requests to any host other than the app's own**, and every screen
  renders in Fraunces and Newsreader with no network beyond the first response. Falsified
  if any screen falls back to a system serif, if any `font-variation-settings` axis in use
  stops working, or if the added repo weight exceeds **250 KB** total.
- **Lane:** Express (same-day, reversible). One commit, revertable by restoring three
  lines of `_head.html.erb`.

## The constraint that decides the implementation

**These are variable fonts and the product uses the axes.** `application.css` sets
`font-variation-settings: "opsz"` at **60** (`.masthead__brand`), **100**
(`.label__title`, and again at line 463), and story 0008's app icon uses **144**. Italics
are live too — `.masthead__label` and `.coda__line` are `font-style: italic`.

So this is **not** a matter of downloading a few static weights. It needs the variable
`woff2` files, roman and italic, for both families:

| Family | Axes in use | Files |
|---|---|---|
| Fraunces | `opsz` 60/100/144, `wght` 380–560, italic | variable roman + variable italic |
| Newsreader | `opsz`, `wght` 380–560, italic | variable roman + variable italic |

Latin subsetting is where the weight budget is won. A static-weight substitution would
silently flatten `opsz`, which is the whole reason the masthead and the wall label look
different at different sizes — it would be a visual regression disguised as an
optimisation.

**The specific lever for the 250 KB budget:** Fraunces ships four axes — `opsz`, `wght`,
`SOFT`, `WONK` — and this product uses two. Pinning `SOFT` and `WONK` to their defaults
during subsetting, alongside a latin-only unicode range, is what makes the budget
reachable. If it still cannot be met with both italics included, the honest move is to
record the real number and revise the prediction, not to drop an axis the design depends
on.

## Scope

**In:**
1. Four variable `woff2` files (Fraunces roman/italic, Newsreader roman/italic), latin
   subset, in `app/assets/fonts/` — a new directory Propshaft already serves.
2. `@font-face` declarations in `application.css` with `font-display: swap` and the
   correct `font-weight` / `font-style` ranges so the variable axes stay live.
3. Delete lines 27–29 of `_head.html.erb`.
4. The OFL licence text committed alongside the fonts, as the licence requires.
5. A test that fails if a third-party font host comes back (R1 — see below).

**Out:**
- Bundling the same fonts into the iOS target. That is story 0008's E2 error view, and it
  reads from the files this story adds.
- A Content Security Policy. Self-hosting makes `font-src 'self'` possible; writing the
  policy is its own decision.
- Any change to the type scale, weights, or the token table. This story changes **where
  the fonts come from and nothing else.** A visual diff is a failure, not a bonus.

## Forcing function (R1)

An artifact without its enforcement is a wish. `test/system/design_test.rb` already
measures `bodyFont` and `brandFont` and fails on drift, which catches a fallback to
Georgia. It does **not** catch the fonts loading correctly *from Google*.

**Added:** an assertion that the rendered `<head>` contains no `fonts.googleapis.com` or
`fonts.gstatic.com` reference. Cheap, and it is the only thing standing between this fix
and someone pasting the Google embed snippet back in six weeks from now.

## Why this ships before story 0008

1. It is Express and reversible; 0008 is Full and two days.
2. Story 0008's error view needs Fraunces and Newsreader **bundled in the app target**,
   because an offline error screen by definition cannot fetch them. Doing this first means
   the files are already in the repo and that task becomes a copy rather than a sourcing
   job.
3. **WIP = 1 holds.** Story 0008 is design-reviewed but has no code. This ships and closes
   before 0008 starts.

Renumbering: push notifications, previously earmarked 0009, becomes **story 0010**.
