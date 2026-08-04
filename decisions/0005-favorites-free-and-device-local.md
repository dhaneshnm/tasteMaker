# 0005 — Favorites are free forever, and they live on the device

Date: 2026-08-04

Position: a reader keeps works with one tap, with no account, no email, no
sign-up and no interstitial. Identity is a random token in a permanent signed
cookie; the table stores only its SHA256, so the column is not a credential. The
collection is **free permanently** — no count limit, no gate, no "upgrade to keep
more", and it is never used as leverage in any future premium decision.

This is the one promise in the product that is not a feature. Persona 2 is the
loudest pain in the review corpus (~6 of 31) and the pain is not "I want a
favorites button" — it is *"all of my favorite pieces, collected over multiple
years, are out of reach, locked behind a paywall I cannot afford."* Persona 6 is
the same person after the betrayal. The category leader built the collection,
taught people to depend on it, then charged rent on it, and that single move is
most of why its reviews look the way they do. Not doing it is the cheapest
durable advantage available to us.

The cost accepted, stated plainly: **device-local means deleting the app deletes
the collection.** That is a real version of persona 2's fear with a different
cause, and this decision does not fix it. What it refuses to do is build accounts
speculatively — Action Mailer is deliberately off in `config/application.rb`, a
signup wall would sit in front of the calm that is one of only two moats we have,
and BET.md wants the app in the App Store by Aug 14 with the iOS shell and push
still unbuilt. On ship day a collection holds one work. The product says the limit
out loud on the collection page ("Kept on this device — free, and yours") so it is
a stated limit rather than a future surprise.

Prediction, falsifiable at the Aug 31 2026 kill review: **no reader will ask for
their collection on a second device before the kill review**, because at 50
installs and 30 days of content there is not enough collection to miss. If
somebody does ask, that request is the trigger below firing early, and it is
better evidence for accounts than any amount of reasoning here.

Enforcement: `test/integration/favorites_test.rb` asserts the cookie carries a
far-future expiry (a session cookie would quietly kill every collection on quit),
that a returning reader with the same cookie sees the same rows, and that the
stored column is a digest rather than anything a cookie could replay. There is no
code path anywhere that gates, counts, or expires a collection — the absence is
the point, and a future reviewer should treat any such path as a violation of this
entry rather than as a feature.

## Triggers, so these get decided rather than drifted into

- **Accounts and export.** The first time a real user asks for their collection on
  a second device, or the first time accounts arrive for any other reason. Then
  `favorites` gains a nullable `user_id` and a claim path. A nullable column added
  later is a migration; an auth system added now is infrastructure for later.
- **A keep control on `/feed`.** The Phase 3 gate, or a real user asking for it in
  one of BET.md's five conversations — not a hunch mid-build. Today the day page's
  own coda says "Wander the full gallery →" and the gallery is the one room where
  keeping does not work; that dead end is accepted on purpose, because a wishlist
  over 110 museum works is persona 4's reference browser and would spend the
  single "New" slot months early and by accident.
- **Per-row remove on the collection.** A user asks, or a collection passes ~50
  rows. Today removal is the same toggle on the work's own page, because a button
  inside a row that is already one link is an accessibility defect.
- **Analytics keyed to the collector token.** Forbidden. If it is ever wanted, the
  App Store privacy-label determination is redone first (session gate 6), not
  after.
