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

**0. `/plan-design-review`** — significant front-door UI. Owner-flagged questions:
   invitation copy and the timer's visual voice (ambient, not a countdown clock — a
   progress hairline? the ornament ✦ filling? nothing visible at all?); what the
   completed minute does (auto-unfold vs. affordance change — protocol says the
   reveal is earned, calm bar says never startle); where the impression field sits
   relative to the invitation; whether `/days/:date` gates identically or archive
   days skip the timer (a reader walking the archive hits N gates in a row —
   probably gate `/` only, fold-without-timer on archive; review decides).
   **Invitation + field placeholder copy are the owner's words, not generated** —
   same rule as notification copy (story 0010 precedent).

**1. The gate, with its tests.**
   - `daily/_day.html.erb`: wrap the note block (both `hand_written?` branches) in
     the `<details class="sit">` structure + invitation line. Applies to
     `:front_door` and `:archive` per step-0's call; `:preview` never gates (the
     curator is proofreading, not practicing).
   - New `sit_controller.js` (Stimulus): timer start on connect, `visibilitychange`
     pause (a backgrounded tab is not looking), completed-minute affordance change,
     localStorage read on connect (already revealed today → open immediately, no
     timer), write on toggle open.
   - CSS: `.sit` styles on linen, `label__note` untouched inside.
   - Tests: system test — note folded on load, reveal control opens it, revisit
     with localStorage mark starts open (Capybara `execute_script` to seed
     storage); `public_cache_headers_test.rb` — `/` still `public, no-cache`, ETag,
     zero `Set-Cookie` (the assertion that already exists must stay green, plus one
     new assertion that the gate markup is present in the anonymous render);
     dynamic-type viewport test if the invitation adds height above the fold.

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
     absent field is not a missing control, unlike Keep's mark).
   - Tests: model validations; integration — anonymous frame request bounces,
     signed-in gets the field, create writes one row, second create for same
     painting updates-or-rejects (step-0/eng call: probably update — a corrected
     first impression is still a first impression), cache headers on `#control`
     private/no-store; system — write a line, reveal, line persists above the note.

**3. The juxtaposition.** After reveal, a submitted line renders above the note,
   styled as the reader's own voice (distinct from editorial). If empty, nothing
   renders — no scaffold for a thing that didn't happen. System test covers both.

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
- **`/days/:date` walk**: N consecutive gates while walking the archive would be
  hostile. Step-0 decides; default position = timer on `/` only.

## Deviations (implement-time — none yet)
