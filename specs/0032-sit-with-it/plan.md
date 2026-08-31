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
- **D5 — Impression field is invisible until the ready state, and its frame has
  NO `src` until then (eng E3, outside voice).** The cached page ships an inert
  `turbo_frame_tag` with no `src`; `sit_controller` assigns the `src` at
  minute-complete. Consequences, all good: no request at all for signed-out,
  device-only, and early-reveal readers — the overwhelming majority of opens;
  no hidden-lazy trap (a `loading: lazy` frame inside `display:none` never
  intersects and would never load); no zero-footprint test gymnastics — an
  inert frame has none by construction. The capture still lands
  protocol-faithfully AFTER a beat of looking. Early reveal (< 60s tap) = no
  field this visit, and **foreclosure is permanent and intended** (outside
  voice OV11): the sit is the moment, like the notebook — a reader who tapped
  through without writing does not get a make-up window. Skipping is free and
  unmeasured-against.
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
| Gate | revealed | note fades open; localStorage mark written; summary stays (a `<summary>` cannot be removed from an open `<details>`) — it dims to a plain label, remains a live toggle, and re-collapsing a revealed note is allowed, harmless, styled, and tested (OV10) |
| Gate | revisit, same day | note open from the start, no timer |
| Gate | no JS | native `<details>`: summary reads as the reveal control, tap opens, no timer |
| Gate | storage blocked | gate shows again next visit — degradation, never an error |
| Gate | Turbo restore/back | idempotent: already-open stays open, timer never restarts |
| Field | any reader, < 60s | inert frame, no `src`, no request, no footprint |
| Field | signed out, ready | `src` fires; `#control` ANSWERS with an empty frame — no link, no form, no text, no cookie (eng A1/OV1: a wall bounce paints Turbo's "Content missing"; the wall's 401 frame carries a Sign-in link — both banned here; asserted on the response body) |
| Field | device-only, ready | empty frame too — the branch is `current_user.present?`, NEVER `identified?` (OV2: a registered device passes `require_reader`; branching on identity would hand it a field whose POST 500s on `user_id null: false`) |
| Field | signed in, ready | field fades in with a VISIBLE label (never placeholder-as-label) |
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
     dim→gold, `aria-live="polite"` — never auto-open, D3), localStorage write on
     toggle open, `clearTimeout` in `disconnect`, idempotent on Turbo restore
     (open stays open, timer never restarts). Duration reads from
     `data-sit-duration-value` (default 60) so system tests set a sub-second
     minute instead of sleeping (eng T-gap).
   - **Revisit-open happens PRE-PAINT, not in `connect` (eng A3):** Stimulus
     connects after first paint, so opening there = a fold→open flash on every
     same-day revisit — the inverse of the banned paint-open-then-fold. A tiny
     inline `<script>` beside the details element reads localStorage
     (try/catch) and sets `open` before paint — the story-0031 precedent (the
     share reveal is a pre-paint inline script in `layouts/_head.html.erb` for
     the same reason).
   - **localStorage shape (eng A4):** ONE fixed key (`sit`), value = the served
     date string read from the DOM (`scheduled_on`, server-rendered — never the
     client clock, which breaks the per-timezone rollover). Overwritten daily;
     no per-date key accumulation. Mismatch or unreadable = gate shows.
   - Safari compat note [Layer 1]: hide the disclosure marker with
     `summary { display: block }` in addition to `list-style: none` /
     `::-webkit-details-marker` — Safari keeps the triangle otherwise.
   - **`expand_controller.js` joins the touched-file list (OV4, P1):** its
     `connect` measures `scrollHeight > clientHeight` once — inside a closed
     `<details>` both are 0, so the More button on a museum-fallback day would
     stay `hidden` forever and 324-word copy renders clamped with no expander.
     Fix: re-measure on the details `toggle` event (or defer measurement until
     visible). The D12 fallback test exists to catch exactly this — now the fix
     is named, not just the test.
   - **`aria-describedby` swap while folded (OV5, P1):** `_day.html.erb` wires
     the plate to `describedby: "daily-note"`, and accessible-name computation
     flattens referenced content EVEN WHEN HIDDEN — a screen-reader user would
     hear the whole note as the artwork's description while the gate is closed:
     reveal-first by default for exactly them. While folded, `describedby`
     points at the invitation line; the reveal swaps it back to `daily-note`.
     System test asserts both states.
   - **Turbo Back detail (OV9, folds into the pre-paint script):** a restore
     snapshot can arrive OPEN while the fresh identical response is CLOSED —
     open→closed→open flicker unless the pre-paint script also runs on the
     restored document. The inline script is idempotent and the system test
     covers the Back path. (Verify CSP allows the inline script — the 0031
     share-reveal script in `_head` is the working precedent.)
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
   - `ImpressionsController`: `#control` renders the field, or the reader's
     existing line, or an EMPTY matching frame for an unidentified caller —
     **never a bounce**. Eng review A1, verified against source:
     `favorites_controller.rb` carries `skip_before_action :require_reader,
     only: :control` precisely because "bouncing this GET to a page that has no
     `keep_<id>` frame writes 'Content missing' over that placeholder." Mirror
     it: same skip, same class-wide `no_store`. The anonymous answer leaks
     nothing (no form → no CSRF → no session → no `Set-Cookie` — cleaner than
     Keep's null state, assert that in the cache-headers test). `#create` stays
     walled (turbo-frame reply, `#control`'s render path reused). Routes named
     like `favorite_control`.
   - `User` gains `has_many :impressions, dependent: :delete_all` beside
     `has_many :favorites, dependent: :delete_all` (user.rb:11) — account
     deletion must not strand reader-written content (eng A2). Same commit
     updates the gate-6 privacy surfaces: `/privacy` page text and the App
     Store privacy-label notes now cover stored user content.
   - `#create` accepts any existing painting, deliberately (eng Q2): coupling it
     to "today's pick" would 404 the reader who sat at 23:59 and submitted at
     00:01 across the rollover. A signed-in reader writing a line on an
     arbitrary work via curl stores 280 chars of their own data — harmless.
     Body is `strip`ped before validation; blank-after-strip rejected;
     `maxlength` on the field AND a server length validation (eng Q1).
   - Anchor is `painting_id`, recorded (eng A5): a painting re-picked months
     later shows the reader their existing line pre-reveal (write-once blocks a
     second) — protocol note-revisiting, treated as a feature; `daily_pick_id`
     rejected because the impression is about the work, not the calendar row.
   - Front-door frame: `turbo_frame_tag "impression_#{painting.id}"` with **no
     `src`** in the cached page (D5 as amended by eng E3); `sit_controller`
     assigns `data-sit-control-url` → `frame.src` at minute-complete. No
     request for the vast majority of opens; no layout shift by construction;
     the field's arrival is a fade (rule 7); visible label, never
     placeholder-as-label.
   - The `#control`/`#create` identity branch is `current_user.present?` —
     never `identified?` (OV2): a registered device passes `require_reader`,
     and an identity-branch would hand the shell's majority state a field whose
     POST violates `user_id null: false`. Device-cookie cases are first-class
     rows in the integration tests: device GET → empty frame; device POST →
     rejected.
   - Migration note (OV8): `daily_picks.painting_id`'s UNIQUE index is the
     load-bearing assumption behind write-once-per-painting — one comment line
     in the migration names it, so any future relaxation of
     one-day-per-painting trips over this story's contract instead of silently
     showing a years-old line against a rewritten blurb.
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

## Instrumentation — decided at eng review (OV6), no longer deferred

The outside voice caught an R1 violation in the deferral: the named fallback
proxy (impression-write rate) requires signed-in ∧ waited ∧ wrote ∧ first time —
structurally ≈ 0 on a product whose iOS default identity is device-only. The
revert decision would have keyed on noise. Resolved in this plan:

- **Count-only beacon ships with part 1.** One unwalled POST endpoint, no
  identity, no cookie, no body beyond the event name; increments two integers
  on a per-date row (`sit_counters: date, shown, completed` — tiny SQLite
  table, survives container replacement the way `auto_tier` was argued in
  0023). `sit_controller` fires `shown` on gate connect and `completed` at
  minute-complete. The ≥ 20% clause becomes measurable the day it ships.
  Privacy: aggregate, identifier-free; App Store label impact checked at the
  next TestFlight — noted, not assumed zero.
- **Timeline honesty for `decisions/0022` (OV6b):** "within 14 days of the
  first 50 opens" cannot resolve before the Sep 30 kill review on an
  unapproved app — the prediction outlives the experiment's current life. The
  decisions entry says so explicitly instead of implying it gates the review.

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

## Eng review (2026-08-31) — coverage map and failure modes

```
CODE PATHS                                          USER FLOWS
[+] sit_controller.js                               [+] The sit (system tests)
  ├── connect: fresh day        → timer armed         ├── [→E2E] push-shaped open → fold → wait → gold → tap → note
  ├── pre-paint script: revealed→ open, no timer      ├── [→E2E] early open (< 60s) → note, no field, no residue
  ├── 60s → ready swap + aria-live                    ├── revisit same day → open from first paint (seeded storage)
  ├── early open → cancel, no residue (F15a)          ├── write line → submit → keep sitting → reveal → line above note
  ├── visibilitychange pause / zoom keeps running     └── archive walk → NEVER gated (D7)
  ├── disconnect → clearTimeout                     [+] Error states
  └── Turbo restore → idempotent, stays open          ├── create fails / over 280 → --warn line, text preserved
[+] impressions_controller.rb                         ├── storage blocked → gate re-shows, no error
  ├── #control anon → EMPTY frame, no cookie (A1)     └── JS crash → native details still opens (no-JS floor)
  ├── #control device-only → nothing (D6, test it)
  ├── #control user, no line → field
  ├── #control user, has line → read-only line
  ├── #create valid / blank / >280 / duplicate
  └── #create yesterday's painting → 200 (rollover, Q2)
[+] daily/_day.html.erb branches
  ├── front_door gated / archive open / preview open
  ├── hand_written vs museum-fallback (nested More, D12)
  └── credit inside gate (D11 order assertion)
[+] cache: / unchanged public + ETag + no Set-Cookie; #control no_store; anon #control sets NO cookie AND carries no link/form/text (OV1)
[+] dynamic type: signed-in, field present (F6d)
[+] expand_controller re-measure on details toggle → More works post-reveal on fallback days (OV4)
[+] describedby: invitation while folded, daily-note after reveal — both asserted (OV5)
[+] sit_counters beacon: shown/completed increment; no cookie on the POST; per-date row (OV6)
[+] summary post-reveal: dim label, re-collapse allowed + tested (OV10)
```
Every path above lands as a Minitest/Capybara test in its step — no deferred
coverage. Timer paths use `data-sit-duration-value` overrides, never sleeps.

**Failure modes:** anonymous frame answer (A1 — handled + tested); account
deletion stranding impressions (A2 — cascade + tested); fold→open revisit flash
(A3 — pre-paint script); rollover mid-sit (Q2 — allowed + tested); double
submit (unique index + disabled in-flight button); localStorage denied
(re-gates, silent by design); sit_controller exception (native details floor).
No silent critical gaps remain.

**Parallelization:** two lanes exist (gate = views/JS/CSS; capture =
model/controller) but they meet in `_day.html.erb` and the system tests —
sequential implementation recommended at this scale (solo, WIP = 1).

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
- [ ] **T6 (P1, resolved by eng review)** — `sit_counters` count-only beacon,
  ships with part 1 (OV6); privacy-label check at next TestFlight
- [ ] **T7 (P1)** — `expand_controller.js` re-measure on details `toggle` (OV4)
- [ ] **T8 (P1)** — `describedby` swap folded↔revealed + assertions (OV5)

## Deviations (implement-time — none yet)

Design-review-time deviation, recorded: D7 amends the story's "(and
`/days/:date`)" — the gate ships on `/` only.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | quota-dead until late Sep; Claude subagents substituted in both reviews | design voice: 15 findings; eng voice: 12 findings |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAN (PLAN) | 13 issues (A1–A5, Q1–Q2, OV2–OV6, OV8, OV10), 0 critical gaps open |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN (FULL) | score: 5/10 → 9/10, 12 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CROSS-MODEL:** Design pass — 6 convergent, 9 net-new folded, 1 dissent
recorded (write-once; owner's protocol stands). Eng pass — outside voice
converged on A1/A3/A4/A5 and added four P1s the primary review missed
(device-identity branch OV2, no-src frame OV3, expand-inside-details OV4,
describedby leak OV5) plus the instrumentation R1 catch (OV6), all folded.
**One standing strategic challenge (OV12), recorded not applied:** account-backed
capture serves a cohort of ~1 pre-approval; the simpler cut is a device-local
impression line promoted to accounts later. The owner chose account-backed
explicitly on 2026-08-31 with that exact alternative on the table — the decision
stands; this line exists so the choice was challenged on the record, per R9.

**VERDICT:** DESIGN + ENG CLEARED — ready to implement. Owner copy (T5) and
`decisions/0022` (T4) land during implementation, before ship.

NO UNRESOLVED DECISIONS
