# 0031 — Out the door

Date: 2026-08-31
Lane: **Full (≤ 3-day core).** Touches the iOS shell (first bridge component) as well as
the web rails, and the native half rides an App Store binary (1.1 → 1.2) — not
same-day-reversible, so not Express. Owner confirmed the lane 2026-08-31.
Status: Draft. WIP slot: 0029 shipped 2026-08-28 (`SHIPLOG.md`), slot open (R5).

Intake path: owner ask, 2026-08-31, this session — "wherever we have the keep button,
add a share button next to it; share that painting image to any app iOS allows."
Five scoping choices made in the same conversation, recorded below.

## Who

- **Maya** — persona 1, CORE. Opens the push, sees today's work, wants to send it to
  one person. Today the only route is screenshot → crop → paste, which loses the title,
  the artist, and any thread back to the product.
- **The person Maya sends it to** — not a persona, and that is the point. Distribution
  decides this category (settled fact, CLAUDE.md); the product currently has zero
  built-in ways for one reader to put it in front of another. A share sheet is the
  smallest possible one.
- **Jordan** — web reader, guard rail. Sees nothing. This is a shell-only surface by
  owner decision; the web page must stay byte-identical to what it is today, because
  `/` and `/days/:date` are `Cache-Control: public` behind Thruster and a UA-dependent
  render would poison the shared cache — the exact hazard the keep control's
  eager-frame split exists to avoid (`favorites/_control.html.erb`).

## Problem

**A reader who loves a painting has no way to hand it to anyone.** The product's only
distribution channel today is the App Store listing itself. Every keep is a private
act; nothing a reader does inside the app can reach a second person.

Evidence:
- Category settled fact: product commoditized, distribution decides the winner
  (CLAUDE.md, `BET.md`). A share sheet is the one baseline-adjacent surface that turns
  an existing reader into a channel.
- iOS share sheet is the platform-native answer — zero new UI to design beyond one
  glyph, and it reaches "any app iOS allows" by definition (owner's phrasing).
- All images are CC0 (settled fact) — sharing the full-resolution file is legally
  clean and costs nothing.

## Owner decisions (2026-08-31, one question at a time)

1. **Payload (b):** image + text ("*Title* — Artist") + link back to Tondo. Bare image
   carries no pull-back; the link is the distribution half of the feature.
2. **Image (a):** full-resolution cached original, not the on-screen variant. CC0;
   share-to-Photos deserves the real file.
3. **Surfaces (a):** everywhere keep appears — `/` (today), `/days/:date`, `/feed`,
   `/artists/:slug`. Same rail slot, one partial. Works with no image (resting) get no
   share button.
4. **Route (b):** Hotwire Native **bridge component** → native `UIActivityViewController`.
   Web Share API rejected (WKWebView file-share support unverified; bridge is
   guaranteed). First bridge component in the shell — the "genuinely required"
   reasoning goes to `decisions/0021` (R4).
5. **Lane (b):** Full.

## Success signal (falsifiable, R4)

The share link carries `?via=share`. Prediction: **within 14 days of the 1.2 binary
reaching readers, the production log shows ≥ 10 requests carrying `via=share`** —
shared links actually opened by recipients, not taps. Zero such requests in 14 days =
the button is furniture; say so in the kill/keep note rather than defending it.
(Tap counts would need new analytics plumbing; recipient visits are already measurable
in the request log and are the number that actually matters for distribution.)

## Non-goals

- No web share button, no Web Share API fallback. Shell only.
- No share-count, no "most shared" surface, no social anything.
- No per-painting web page. The link target is `/` — the product's only unwalled
  artwork page (eng review E1, 2026-08-31: `/days/:date` and the artist page both
  sit behind the 0015 wall and would bounce an anonymous recipient to sign-in).
  Building `paintings#show`, or unwalling the archive, would be its own story.
- No analytics events, no new tracking. The `via=share` query param on an existing
  page is the whole measurement apparatus.
- No Android anything.
