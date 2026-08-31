# 0032 — Sit with it — plan

Steps in order. Tests land with their step, not after (R1). Deviations found at
implement time get noted back here. `/plan-design-review` (step 0) and
`/plan-eng-review` gate implementation — both pending as of this draft.

## Shape of the change

Three parts, strictly layered so part 1 ships alone if 2–3 slip:

1. **The gate** — client-side only, on the cached public page. Note starts folded;
   soft 60s invitation; reveal never locks. Zero server change.
2. **The impression line** — signed-in capture, one line, stored before the reveal.
   New model + walled endpoint, same two-caller frame idiom as Keep.
3. **The juxtaposition** — after reveal, the reader's own line sits above the
   curator's note. The compare mechanic (protocol step 3) for free, no extra UI.

## The cache line — the constraint everything bends around

`/` is `Cache-Control: public` behind Thruster: byte-identical markup for every
reader, no `Set-Cookie` (story 0007; `public_cache_headers_test.rb`). Therefore:

- The folded note + invitation are **in the cached HTML, identical for everyone**.
  The gate's per-reader state (revealed today or not) lives in `localStorage`,
  try/catch-guarded, key `sit:<scheduled_on ISO date>`. Storage denied or cleared →
  gate shows again; correct degradation, never an error.
- The impression field arrives like Keep does: `turbo_frame_tag` with `src` pointing
  at a walled endpoint. Signed-out visitors' frame request bounces off the wall and
  the page shows no field — no nag, nothing broken.
- **No-JS floor:** the note renders inside a native `<details>` element. Without
  Stimulus the summary reads "Read today's note" and a tap opens it — functional,
  accessible, zero flash-of-unfolded-note (the fold is the server-rendered default,
  not a JS mutation after paint). Stimulus enhances: runs the timer, swaps the
  summary copy when the minute completes, records the localStorage mark on open.
  Design review may replace `<details>` with an equivalent — the two invariants that
  survive any redesign: **no-JS readers can always open the note; the note never
  paints open and then folds.**

## Steps

**0. `/plan-design-review` — RUN 2026-08-31, decisions folded below.** Owner's
   standing review delegation applied (auto-select + record). Mockup generation
   skipped with a named reason: the generator emits generic web mockups that cannot
   be judged against this system's exact tokens and one-skin rule; review ran
   text-against-DESIGN.md instead. Outside voice: Codex quota-dead (resets late
   Sep); Claude design subagent ran independently, findings folded.
   **Invitation + ready-line + field-label copy are the owner's words, not
   generated** — same rule as notification copy (story 0010 precedent). Owner copy
   is owed before ship, reviewed field by field.

## Design review decisions (2026-08-31) — settled, cite don't reopen

- **D1 — Only the note folds.** Title, artist, meta stay visible: a museum hangs
  the wall label beside the painting; identification primes far less than
  interpretation. Folding the whole label would gut quality bar 2 for a purity the
  protocol doesn't ask for.
- **D2 — No visible timer.** The invitation copy names the minute; the note
  becoming ready is the timer's only face. A countdown is a clock on the calmest
  surface in the product. Tripwire: if the dogfood week shows "where's the text?"
  confusion, the considered fallback is a 1px `--hairline` fill, not a numeral.
- **D3 — No auto-unfold.** At 60s the invitation line swaps to the ready copy and
  the reveal control steps `--ink-dim` → `--gold` — the compass's own state idiom
  (dim = not-yet/here, gold = live door; `DESIGN.md` gold-means-link). The reveal
  stays an act the reader performs, which is the protocol's own shape and removes
  the startle/scroll-jump risk of a page changing itself. The swap is announced
  via `aria-live="polite"`.
- **D4 — Reveal control is a `.caps-link` that states its own bar.** `.caps-link`
  sets size and tracking, never height (rule 9, ISSUE-002) — the control declares
  `min-height: var(--tap)` explicitly.
- **D5 — Impression field is invisible until the ready state.** The turbo frame
  (walled `src`) is in the cached page from first paint but its content stays
  hidden until the minute completes — so the frame's late arrival can never shift
  the layout of the calm page, and the capture lands protocol-faithfully AFTER a
  beat of looking, not instead of it. Early reveal (< 60s tap) = no field this
  visit; skipping is free and unmeasured-against. Signed-out: the frame's bounce
  leaves nothing — no nag, no reserved hole.
- **D6 — Write-once.** One impression per painting, no editing after submit — the
  notebook is ink. Over-limit and failure render a `--warn` inline line with the
  reader's text preserved. Eng review may challenge write-once.
- **D7 — The archive is not gated.** `/days/:date` renders the note open, exactly
  as today. The sit is today's ritual; a reader walking the archive would hit N
  gates in a row, which is hostility, not practice. Same-template divergence by a
  local, the established `/` vs `/days/:date` idiom (`chrome:`). **Amends the
  story's "(and `/days/:date`)" — deviation recorded here, not silently.**
- **D8 — The unfold is a fade** (rule 7), instant under `prefers-reduced-motion`.
  Nothing slides.
- **D9 — Bookkeeping ships in the same unit of work (R1):** the `.sit` block gets
  its `DESIGN.md` entry (new visual idiom needs a line), and the front-door ritual
  change gets `decisions/0022` (direction-level, R4) with the falsifiable
  gate-completion prediction from the story.
- **D10 — One server-rendered summary string, for everyone.** The cached page is
  byte-identical, so a separate no-JS "Read today's note" string would paint first
  and get swapped by Stimulus on connect — a copy flash, the textual twin of the
  paint-open-then-fold bug this plan bans. The owner-written invitation itself IS
  the summary/open control, readable both as "sit first" and "open now"; Stimulus
  touches the copy exactly once, at minute completion. (Outside voice F3.)
- **D11 — The credit line moves inside the gate.** Folding the note collapses the
  label's middle, and at 375px the coda's "See you tomorrow." would sit two lines
  under "sit with it for a minute" — "we're done here" against "please stay."
  `label__credit` is reveal material (dim acquisition metadata); the coda stays
  outside — it is the floor of every page. Sit-state order, asserted by a system
  test: plate → rail → title → artist → meta → [frame] → invitation → coda.
  (Outside voice F7.)
- **D12 — The museum-fallback branch keeps the gate, deliberately.** Sit-open then
  More is two sequential unfolds on a fallback day — accepted for ritual
  consistency, and the invitation copy must not promise "the curator's note",
  since some days it isn't one (`decisions/0004`). Fallback-branch tests: More
  functional post-reveal, `label__source` inside the gate. (Outside voice F10.)
- **Frame position is a structural invariant, not a taste call (F1):** the
  `turbo_frame_tag` sits OUTSIDE and ABOVE `<details class="sit">`, last element
  of the pre-reveal stack — inside the details body it would be invisible until
  reveal, which kills the capture's premise. Bonus: after reveal the submitted
  line already sits above the opened note, so the juxtaposition needs zero
  reparenting.
- **Cross-model tension, recorded:** the outside voice argued duplicate-impression
  = update, rendered line as its own edit affordance. **Write-once stands (D6)** —
  the owner's protocol treats the notebook as ink; eng review is the named
  challenger. Adopted from the same finding: submitting the line does NOT open the
  note — writing is not consent to reveal; and in-flight = disabled submit, no
  spinner (`.sentinel` is scroll vocabulary, not form vocabulary).
- **Copy rule:** no guilt language anywhere. "A reveal-first session is a failed
  session" is protocol vocabulary for the owner's own practice — banned from
  product copy, flash text, and accessible names. Early open cancels the timer
  silently and the completion affordance never appears afterward — no "the minute
  is up" residue after the reader already chose (F15a). The zoom overlay does NOT
  pause the timer: zooming is looking — written down so nobody "fixes" it (F15b).

## Hierarchy and states (design review outputs)

**Reading order during the sit:** plate → title/artist/meta → invitation line →
reveal control. **After reveal:** plate → label → reader's own line (only if one
was written — no scaffold for a thing that didn't happen) → note → credit → coda.

| Surface | State | The reader sees |
|---|---|---|
| Gate | first open, JS on | note folded; invitation line; dim reveal control |
| Gate | 60s elapsed | invitation swaps to ready copy; control turns gold; field appears (signed-in) |
| Gate | revealed | note fades open; localStorage mark `sit:<date>` written |
| Gate | revisit, same day | note open from the start, no timer |
| Gate | no JS | native `<details>`: summary reads as the reveal control, tap opens, no timer |
| Gate | storage blocked | gate shows again next visit — degradation, never an error |
| Gate | Turbo restore/back | idempotent: already-open stays open, timer never restarts |
| Field | signed out | nothing — frame request bounces off the wall, no trace |
| Field | signed in, < 60s | present in DOM, hidden |
| Field | ready | fades in with a VISIBLE label (never placeholder-as-label) |
| Field | error / over 280 | `--warn` inline line, reader's text preserved |
| Field | submitted | read-only line above the note after reveal |

**Journey (push → sit):** noon push names the artwork → open lands on the art
full-bleed, unchanged (the push's promise is the art, never the note) → the
invitation is the first *new* thing, quiet, skippable → the minute turning is a
soft state change, not an event → the reveal is the reader's own tap → tomorrow it
re-gates. Skip every day forever and the product never mentions it.

**1. The gate, with its tests.**
   - `daily/_day.html.erb`: wrap the note block (both `hand_written?` branches) in
     the `<details class="sit">` structure + invitation line. **`:front_door`
     only** (D7); `:archive` and `:preview` render the note open exactly as today —
     one conditional local, the template's established divergence idiom.
   - New `sit_controller.js` (Stimulus): timer start on connect, `visibilitychange`
     pause (a backgrounded tab is not looking), ready-state swap at 60s (copy +
     dim→gold, `aria-live="polite"` — never auto-open, D3), localStorage read on
     connect (already revealed today → open immediately, no timer), write on toggle
     open, idempotent on Turbo restore (open stays open, timer never restarts).
   - CSS: `.sit` on linen — summary reuses the existing disclosure type treatment
     (`.label__more` / `.caps-link` vocabulary, Newsreader, existing tracking —
     never a third parallel idiom); summary states its 44px bar via
     `padding-block` (the `.label__artist-name` precedent — it sits in flowing
     text and must wrap); native disclosure marker suppressed explicitly
     (`list-style: none` + `::-webkit-details-marker`) — the chevron is an idiom
     this product has never shown. `label__note` untouched inside.
   - `DESIGN.md`, same unit of work (D9/F4): `.sit` component entry, and a rule 8
     amendment — "the hand-written note is shown whole **once revealed**; its
     entrance is gated by story 0032" — so the gate reads as a decision, not a
     violation, to the next maintainer.
   - Tests: system test — note folded on load, reveal control opens it, revisit
     with localStorage mark starts open (Capybara `execute_script` to seed
     storage); sit-state order assertion (D11); fallback-branch coverage (D12);
     Turbo restore — open-with-no-storage-mark stays open (the never-paints-open-
     then-folds invariant applies to `connect` on restore, not just first paint),
     and timer restart on restore is recorded as invisible-and-harmless BECAUSE
     there is no timer visual (F13 — if a visual is ever added, restart becomes a
     punitive reset and this reason must be re-argued);
     `public_cache_headers_test.rb` — `/` still `public, no-cache`, ETag, zero
     `Set-Cookie`, plus one new assertion that the gate markup is present in the
     anonymous render; dynamic-type viewport test runs SIGNED-IN with the field
     present — that is the taller pre-reveal state (F6d).

**2. The impression model + endpoint, with its tests.**
   - Migration: `impressions` — `user_id` (null: false, FK), `painting_id`
     (null: false, FK), `body` (string, limit 280), timestamps; unique index on
     `[user_id, painting_id]`. **User-only, no device identity**: the owner's call
     was durable, account-backed capture; a device-identified reader sees the gate
     but no field. (Deviation from Keep, which accepts devices — recorded here, and
     the eng review should challenge it if wrong.)
   - `Impression` model: `belongs_to`, presence + length validation, one per
     user+painting (validation AND index).
   - `ImpressionsController`: `#control` (renders field or the reader's existing
     line; answers unidentified callers with an empty frame the way
     `favorites#control` answers them with a bounce — same wall, same
     `private, no-store` headers), `#create` (turbo-frame reply, `#control`'s
     render path reused). Routes under the walled block, named like
     `favorite_control`.
   - Front-door frame: `turbo_frame_tag "impression_#{painting.id}", src:` inside
     the gate's pre-reveal area, default content empty (no placeholder glyph — an
     absent field is not a missing control, unlike Keep's mark). Field content
     hidden until the ready state (D5) so the frame's arrival never shifts layout;
     the EMPTY frame is asserted to have zero footprint — an empty
     `turbo_frame_tag` with a class can still carry padding, and signed-out
     readers must get literally no shift (F6c); visible label on the field, never
     placeholder-as-label; the field's arrival at ready-state is a fade (rule 7).
   - Tests: model validations; integration — anonymous frame request bounces,
     signed-in gets the field, create writes one row, second create for the same
     painting is rejected (write-once, D6), cache headers on `#control`
     private/no-store; system — write a line, reveal, line persists above the note.

**3. The juxtaposition.** After reveal, a submitted line renders above the note —
   already in DOM position thanks to the frame invariant (F1), zero reparenting.
   The reader's voice, in tokens not vibes (F14): Newsreader italic, `--ink-dim`,
   body size, no quotation marks, no box or card (rule 6), one line-height of
   space above `label__note`. New text idiom → rides this step's `DESIGN.md`
   entry. If empty, nothing renders — no scaffold for a thing that didn't happen.
   System test covers both.

**4. `bin/ci` green, then `/qa`, `/simplify`, `/code-review`, re-verify, ship** —
   the standing flow, steps 5–9 of CLAUDE.md.

## Instrumentation — minimal, honest

The post-live success signal (story: ≥ 20% of opens let the minute complete) needs a
receipt. Cheapest honest instrument: the localStorage mark distinguishes
completed-vs-early only client-side, and shipping analytics events for it is a
gate-6/privacy-label conversation. **Deferred to its own decision at eng review**:
either a single count-only beacon (no identity) or accept that the first 50-open
read comes from the impression-write rate + founder observation, and instrument
later. Do not silently ship tracking.

## Risks / open questions for the reviews

- **App Review optics**: a first-run reviewer sees a folded note. The reveal control
  is always visible and the artwork is the page — low risk, but name it in the
  TestFlight notes when 1.2+ ships this.
- **Push → gate interaction**: the noon push (story 0010) lands the reader on `/`
  mid-day. Gate shows on first open only (localStorage) — the push's promise
  ("today's artwork") is the artwork, which is never folded. No conflict, assert in
  QA script.
- **Turbo Drive cache**: navigating away and Back must not re-run the timer against
  an already-open `<details>` — `sit_controller` must be idempotent on
  `turbo:morph`/restore visits. Test explicitly.
- ~~**`/days/:date` walk**~~: resolved by D7 — the archive is not gated at all.

## Design review — NOT in scope (considered, deferred, one line each)

- Guided regions / pan (shape B) — own story, waits for A's signal.
- Any timer visual — D2; tripwire named, fallback pre-chosen (`--hairline` fill).
- Editing a submitted impression — write-once (D6); eng review is the challenger.
- Streak/consistency mechanics — guilt machinery; violates the calm bar by design.
- Instrumentation beacon — deferred to its own decision at eng review (gate 6).
- A `/you` preference to disable the gate — becomes the REVERT path if the
  post-live signal fails (story's success section); not shipped speculatively.

## Design review — what already exists and is reused

- `<details>`/`summary` disclosure with `.label__more`/`.caps-link` type
  treatment — no third disclosure idiom.
- Keep's two-caller walled turbo-frame architecture (`favorites#control`) for the
  impression field; its `private, no-store` header contract.
- Gold-means-link state semantics (dim = not-yet, gold = live door) for the
  ready-state swap — the compass taught it.
- `chrome:` local divergence in `daily/_day.html.erb` for front-door-only gating.
- Rule 7 fades; rule 9 `--tap` + `padding-block` (`.label__artist-name`
  precedent); `--warn`'s one sanctioned job for the field error line.
- TODOS.md: this repo routes deferred work through `IDEAS.md`, not TODOS.md — the
  one candidate (revert-to-preference path) is already encoded in the story's
  success signal; nothing new queued.

## Implementation Tasks
Synthesized from this review's findings. Checkbox as you ship.

- [ ] **T1 (P1)** — gate — `<details class="sit">` + `sit_controller.js` + CSS +
  rule-8 amendment + `.sit` DESIGN.md entry + full test set (plan step 1; D1–D4,
  D7, D10–D12, F13, F15)
- [ ] **T2 (P1)** — capture — `Impression` model, migration, walled controller,
  zero-footprint frame (plan step 2; D5, D6, F1, F6)
- [ ] **T3 (P2)** — juxtaposition — reader-voice tokens + DESIGN.md entry (plan
  step 3; F14)
- [ ] **T4 (P1)** — `decisions/0022` — front-door ritual change, falsifiable
  prediction from the story (D9, R4)
- [ ] **T5 (P1)** — owner copy pass — invitation/summary (doubles as open
  control, D10), ready line, field label, error line; reviewed field by field
- [ ] **T6 (P3)** — instrumentation decision at `/plan-eng-review` — beacon vs
  impression-rate proxy; privacy label impact

## Deviations (implement-time — none yet)

Design-review-time deviation, recorded: D7 amends the story's "(and
`/days/:date`)" — the gate ships on `/` only.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — (quota-dead until late Sep; Claude subagent substituted) | 15 findings, 6 convergent, 9 folded, 1 dissent recorded |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 for this plan | NOT RUN (prior entries are story 0031's, stale by commit) | — |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN (FULL) | score: 5/10 → 9/10, 12 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CROSS-MODEL:** Claude subagent outside voice vs. primary review — 6 findings
convergent (no timer, no auto-unfold, archive ungated, aria-live, hidden-until-
ready field, DESIGN.md debt), 9 net-new folded (frame position invariant, single
summary string, credit-inside-gate, marker suppression, fallback-branch nesting,
restore policy, zero-footprint frame, reader-voice tokens, early-open/zoom timer
sentences), 1 dissent recorded in the owner's favor (write-once impressions; eng
review is the named challenger).

**VERDICT:** DESIGN CLEARED — eng review required next (`/plan-eng-review` has
not run against this plan; the 2026-08-31 log entry belongs to story 0031).

NO UNRESOLVED DECISIONS
