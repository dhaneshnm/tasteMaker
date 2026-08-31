# 0032 — Sit with it

Date: 2026-08-31
Lane: **Full (≤ 3-day core).** The gate itself is a same-day client-side change, but the
impression capture adds a model, a migration, and a walled endpoint — not same-day
reversible. Significant UI on the front door → `/plan-design-review` required before
implementation.
Status: Draft. WIP: story 0031 merged + SHIPLOG'd 2026-08-31; its remaining items
(LAN device QA, TestFlight 1.2, deploy) are owner-gated device/App-Store actions,
explicitly deferred by the owner this session — named here, not hidden.
Numbering: 0032 taken at this promotion. "The standing bar" (dark branch
`0030-the-standing-bar`) takes the **next free number** when picked up — corrects the
story-0031 SHIPLOG row's guess that it would take 0032.

## Who

- **Maya** — persona 1, CORE (`specs/personas.md`). Opens with tea, reads the blurb in
  1–3 minutes, closes. Her success signal is already written in the persona, verbatim
  from the 8.8K-comment corpus: **"I never noticed that she doesn't have eyebrows.
  That's all I can look at now."** — the noticing report. Today's page gives her no
  route to that moment: the note sits directly under the artwork, and reading is
  easier than looking, so she reads. The text tells her what to see before her eyes
  have tried.
- **The owner, as dogfooder** — the slow-looking protocol (5 sits logged, avg 12 min,
  endings = saturation not fatigue) is this feature's paper prototype. The app version
  is the 60-second reader-scale cut of the protocol's first step, not the protocol.

## Problem

**The front door hands the reader the reveal before the look.** The daily note — the
product's one moat surface — renders in full under the artwork on first paint. The
slow-looking practice this app grew from orders it the other way: look first, then
read; "a reveal-first session is a failed session" (protocol v2). Four DM exchanges
with r/ArtHistory commenters (`user-research/0009`) say the scarce goods in this
category are structure and vocabulary, not content — and the one practitioner asked
for a looking framework had none to give ("no real secret, just don't overthink it").
The reader who would like to look first gets no help; the reader who never thought to
look first never finds out looking is a thing this app believes in.

Novice failure mode is premature saturation — "seen it" at 90 seconds, scroll on —
not fatigue (owner dogfood: motivated saturation lands ~12 min; a lay reader's lands
in low single digits). Sixty seconds of protected looking is ~8% of the founder's own
average: a floor, deliberately modest.

## Story

On `/` (and `/days/:date`), the note starts **folded**. In its place, one quiet line
in the editorial voice invites the reader to sit with the artwork for a minute before
reading. A soft, ambient 60-second timer runs; when it completes, the note unfolds (or
the invitation becomes an obvious "read the note" affordance — design review's call).

**The gate never locks.** A visible control opens the note immediately at any moment —
Maya on a 4-minute tea break is not held hostage, calm bar intact (Better #4: nothing
between push and art — the art IS the first paint, unchanged; this folds only the
text below it). Reveal-early is allowed and unmeasured-against; the gate is an
invitation with a default, not a wall.

**Signed-in readers get one optional line before the reveal**: "first impression — one
line, before the note" (placeholder wording TBD at design review). Stored server-side
on the reader's account (owner decision, 2026-08-31 session: notes are account-backed;
device-local favorites stay device-local per `decisions/0005`). Signed-out readers see
gate + reveal only — no capture field, no sign-in nag on the calm surface.

Per-device, per-day memory (localStorage, try/catch-guarded): once today's note is
revealed, revisits today skip the gate. Tomorrow re-gates.

## Cache constraint — carried from stories 0006/0007/0020, not renegotiated

`/` is `Cache-Control: public` behind Thruster; identical markup for every reader; no
`Set-Cookie`. The gate is therefore **client-side only**: the cached page carries the
folded note and the invitation for everyone; Stimulus runs the timer and the unfold.
The impression field ships the way Keep does — a turbo frame pointing at a walled
per-visitor endpoint, machinery arriving after first paint. No server-side UA or
reader branching on the public page. `public_cache_headers_test.rb` holds the line.

## Evidence

- Protocol dogfood: 5 sits, avg 12 min, saturation endings, trained-eye delta survived
  5/5 — the look-then-read loop holds for its most motivated user
  (`slow-looking-protocol-v2.md`, to be committed under `user-research/` with this
  story).
- `user-research/0009`: 4/4 DM exchanges — structure + vocabulary are the scarce
  goods; trainable but not teachable; "having the names weirdly made me see them more
  clearly."
- Persona corpus: Maya's noticing report (above); "perfectly proportioned little
  description" — the note stays whole and unchanged, only its *when* moves.
- r/ArtHistory threads 1vuknft + 1vqubg3 (the posts the DMs grew from).

## Success signal — falsifiable, time-bound

- **Pre-live (dogfood):** the owner's remaining 10 protocol screen-sits use this page
  as the display surface, and the gate survives 7 consecutive days of the owner's own
  daily open without being reflexively skipped. Reflexive skip every day = the
  invitation copy or shape is wrong; rework before any reader sees it.
- **Post-live:** within 14 days of the first 50 front-door opens (whenever that
  arrives — app not yet approved), **≥ 20% of opens let the timer complete before
  revealing**, and at least one signed-in reader writes an impression line
  unprompted. Below that, the gate reverts to a preference (default off) rather than
  the default experience — the revert is one Stimulus default, which is why the gate
  half is same-day reversible.

## Non-goals

- Guided detail regions, pan/zoom tour, per-region curator lines — shape B, own story,
  waits for authoring-cost evidence and the finished 15-sit dogfood.
- Audio capture, uploads, transcription — owner's stated end-state, not this story.
- Theme word, prompt rotation, glossary, compare mechanic — protocol features whose
  app translation is unproven until the dogfood finishes.
- Any change to the note's content, length, or voice. The blurb is untouched; only
  its entrance moves.
- No New-slot claim. This is **Better-bucket sequencing** (build order: blurb craft /
  art-and-text-together get a *when*, not just a *what*). The New slot stays deferred
  in `BET.md` for the Phase 3 gate; shapes B/C are the candidates that would claim it.
