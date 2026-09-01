# 0033 — Whose words

Date: 2026-09-01
Lane: **Full (≤ 3-day core).** View/CSS/JS restructure of the front door's words
section plus small controller-variant and beacon changes — no new model, no
migration beyond none. Significant UI on the front door → `/plan-design-review`
required before implementation.
Status: Draft. WIP: 0032 shipped and deployed 2026-09-01 (7068668 + gate live);
its owed prompt-copy pass remains owner-gated, named not hidden.
Numbering: 0033 taken at this promotion. "The standing bar" (dark branch
`0030-the-standing-bar`) still takes the next free number when picked up.
Branch: `0033-whose-words`.

## Who

- **Maya** — persona 1, CORE. Opened the revealed page (0032 live, same day) and
  the two voices ran together: her own line and the museum's paragraph are both
  serif prose in one column. She cannot tell at a glance where her words end and
  the institution's begin.
- **The owner, as dogfooder** — hit exactly this on the first production open of
  the 0032 reveal (screenshot, 2026-09-01 09:52): "The user input and app note
  are not clearly distinguishable."

## Problem

**The revealed page interleaves two voices with no attribution.** After the sit,
the reader's answer (display italic, dim) sits directly above the museum/curator
note (body roman, ink) — different faces, but at reading distance one run of
prose. Nothing names whose words are whose, and the note — borrowed institutional
copy on fallback days — carries no visual authorship at all until the small-caps
source line at the very bottom.

A secondary problem the first mock round surfaced: the words section as a whole
has no door. It is simply *there* under the meta line, so the page cannot be
"just the picture" once revealed — the calm surface always carries the full text
column.

## Story

The words section becomes **a comment thread** — the grammar every reader
already knows for whose-words-are-whose — behind one rail control:

1. **A comment glyph joins the rail** (between zoom and keep, keep's growing
   frame stays last). It shows/hides the entire conversation section. Ink like
   its neighbors when closed, gold while open. **Open by default**; a reader who
   closes it stays closed for the day.
2. **The museum/app note is the pinned comment** — and it is **collapsed by
   default**. One header row: pin glyph + "Pinned · Cleveland Museum of Art"
   (hand-written days name the house voice instead — design review names it)
   + chevron. Tapping expands the note body with the credit line as its meta
   row. Collapsed on every load, never persisted — the note always costs one
   deliberate tap. Write-first survives 0032's gate removal by this fold.
3. **The reader's answer is their comment**, Instagram run-in form (mock
   variant C): monogram medallion, bold run-in "You" then the answer text in
   the reader's italic, relative time as meta ("this morning").
4. **Prompt XOR reply.** Until the reader has answered, their comment slot is
   the composer: the day's prompt as the field's visible label over the ruled
   autosave input (0032 machinery unchanged). Once answered, prompt and field
   are gone — only the answer renders, as a comment. The revealed-prompt
   caption state dies.
5. **The keep count leaves the rail** ("5 kept" text removed; the keep glyph
   stays, fills when kept).

Approved clickable prototype (the contract for this story):
https://claude.ai/code/artifact/faed9c6b-efa8-429f-b350-549b155de7ba
Mock comparison board (variants A/B/C; C chosen):
https://claude.ai/code/artifact/7cff7527-61b4-43a5-a83e-a0f5be90548f

## Cache constraint — carried, not renegotiated

`/` stays `Cache-Control: public`, byte-identical, zero `Set-Cookie`
(`public_cache_headers_test.rb`). The thread shell, pinned comment, and glyph
are cached markup identical for everyone; toggle and fold are client-side; the
reader's comment/composer stays the per-visitor impression frame exactly as
0032 built it.

## Evidence

- Owner dogfood of the live 0032 reveal, day one: the distinguishability
  failure, with screenshot — the direct trigger.
- Three mock rounds, 2026-09-01: label-side treatments (six variants) →
  comment-thread direction (three variants) → clickable prototype iterated
  twice (pinned fold, default-open, count removal). Variant C picked by the
  owner against A/B on the board.
- Comment-section grammar is the one attribution idiom readers bring with them
  — pinned = the house, run-in name = the author. No teaching required.

## Success signal — falsifiable, time-bound

- **Pre-live (dogfood):** 7 consecutive days of the owner's daily open on the
  thread page; the pinned fold is expanded on the days the owner actually wants
  the note and never reflexively on the rest. Reflexive expand-every-open =
  the fold is friction theater; rework before readers see it.
- **Post-live (amended at eng review, 2026-09-01 — OV5):** within 14 days of
  the first 50 front-door opens, **≥ 30% of thread-seen days expand the
  pinned note** — both beacons dedupe once per client per day, so the ratio
  is "fraction of daily lookers who opened the note," numerator ⊆
  denominator by construction — and **at least one signed-in reader besides
  the owner writes an answer** in the window. (The first draft compared
  against "the 0032 baseline"; no such baseline exists — 0032 reached
  readers for zero days.) Fail either → the medallion/thread dress retreats
  to the ledger layer (cheap); reverting the thread structure itself is a
  multi-file restore, costed honestly in the decisions entry — not "one
  partial swap."

## Non-goals

- No likes, replies, threading, or any second commenter. Two voices, ever:
  the house and the reader. This is attribution dress, not social features.
- No comment counts anywhere (the "2 comments" affordance was considered on
  the board and dropped with the kept-count).
- No change to note content, prompt rotation, autosave, impressions model, or
  the walled-endpoint architecture.
- No archive gating change: `/days/:date` keeps its browsing posture (thread
  visible, pinned expanded by default — plan details it). No New-slot claim:
  this is Better-bucket execution (bar 2: art + text; bar 4: calm).
