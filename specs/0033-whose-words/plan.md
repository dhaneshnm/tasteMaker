# 0033 — Whose words — plan

Steps in order; tests land with their step (R1). Deviations get noted back here.
`/plan-design-review` (significant front-door UI) and `/plan-eng-review` gate
implementation — both pending as of this draft.

The approved prototype is the contract:
https://claude.ai/code/artifact/faed9c6b-efa8-429f-b350-549b155de7ba
Every behavior in it is enumerated below; anything the prototype shows that a
step omits is a plan bug.

## Shape of the change

Three layers plus one removal, strictly ordered so each ships alone:

1. **The thread shell** — comment glyph in the rail toggling the conversation
   section; section open by default. Kills 0032's `<details class="sit">` /
   "Read the note" summary.
2. **The pinned comment** — the note (whichever voice) folds into a pinned
   comment row, collapsed by default, native `<details>` under the hood.
3. **The reader's comment** — prompt XOR reply in the impression frame: composer
   until answered, run-in comment after.
4. **Keep-count removal** — "N kept" leaves the rail everywhere it renders.

No new model. No migration. The impressions architecture (walled frame,
autosave) is retained machinery wearing new clothes; its two behavioral
amendments — the ink boundary moving to day's end and blank-as-delete — live
in the controller and views, not the schema (steps 3, eng OV1/OV2).

## What the mock rounds fixed as behavior (the full inventory)

- Rail order: zoom → **comment bubble** → keep. Keep's growing frame stays
  last (0031's no-shove rule). Bubble: `--gold` in BOTH states — outline
  closed, **filled open** (DR15, a recorded prototype deviation: the rail's
  constant is gold and dim-in-a-gold-row reads *disabled*; fill-for-state is
  the grammar Keep already taught, so the rail keeps one state language).
  `aria-expanded` + `aria-controls`, labels "Read the notes"/"Hide the notes".
- Conversation **open by default**. Closing it is remembered **for the day
  only** (localStorage, served date value — same discipline as the 0032 `sit`
  key; new day reopens). Pinned fold is **never** persisted: collapsed on
  every load, the note always costs one deliberate tap. **The polarity trade
  is named, not hidden (DR3):** the reader who wants "just the picture" pays
  one close per day forever, because fresh words deserve a fresh chance.
  Tripwire: if the dogfood week shows reflexive daily re-closing, the memory
  goes sticky-until-reopened.
- **`.conv` boundaries (DR2):** the section contains the pinned comment and
  the impression slot — nothing else. The coda stays OUTSIDE: closing the
  bubble must never delete "See you tomorrow." and the page's two doors.
  DOM order inside: **pinned comment first, reader's slot second** (DR1).
  This retires 0032's F1 (reader's voice above the curator's) by name, not
  silently: F1's argument was write-first juxtaposition at a reveal moment;
  the reveal moment is gone, the pinned fold now carries write-first (the
  note costs a tap the composer doesn't), and a pinned thing that isn't
  first isn't pinned. Pin-first also makes DR8's CSS sibling selector work.
- Pinned comment anatomy: monogram medallion → header row = pin glyph +
  "Pinned · <voice name>" + chevron → body = note text + credit line as the
  meta row. Museum days name the museum ("Pinned · Cleveland Museum of Art");
  hand-written days name the house voice: **"Tondo", monogram "T"** (D-Q1
  resolved). "Pinned" is plain small-caps `--ink-faint` text + glyph — never a
  chip, pill, or fill (DR14, rule 6). The chevron shows two static
  orientations, swapped instantly — no rotation transition (DR13, rule 7:
  motion is a fade; nothing rotates either).
- Medallion spec, transcribed from the prototype so nobody re-invents it
  hotter (DR12): 32px circle, `--bg-lift` fill, 1px `--hairline` border,
  monogram Fraunces 500 in `--gold-deep`. NOT a gold fill — no gilt-tile
  collision with the 0017 amendment's tripwire. `aria-hidden`. Build order is
  the retreat's insurance: variant A's ledger markup is the base, medallions
  layer on as CSS — if the dogfood week reads "social chrome," the retreat is
  deleting a layer, not rebuilding markup.
- Reader's comment anatomy (variant C run-in): medallion → run-in name "You"
  into the answer text → meta row, relative time. The name is a **`<span>` at
  weight 500** — never `<b>` (DR11: DESIGN.md's "weight range stays 380–560;
  nothing is bold"; a bare `<b>` renders 700). Roman-vs-italic carries the
  contrast: name roman ink, answer keeps the reader-voice italic.
- Relative time vocabulary (DR22): **"today"** when the answer's date is the
  server's America/New_York day, the date otherwise — one word, always true,
  no "this morning" lies at 9pm. Rendered as `<time datetime>` server-side
  inside the private frame; no client clock is ever consulted (the 0032 sit-key
  rule, same reasoning).
- **Prompt XOR reply.** Composer state: prompt as the field's visible label
  (`aria-labelledby` unchanged) over the ruled autosave input + SAVED whisper.
  Answered state: prompt, field, and whisper all gone — the comment alone.
  `.sit--revealed` prompt-caption CSS dies. The prompt lives inside the frame
  (see Cache line, DR6) so the XOR is server-rendered per state, never a
  client-side deletion.
- **Commit semantics (DR4 — the blur-freeze fix; critical).** Autosave fires
  on debounce, Enter, and blur. Only **Enter** transitions composer → comment
  in place; blur and debounce save the draft silently and the composer stays
  editable — a reader who typed three words and tapped the pinned note must
  NOT find their half-sentence frozen into a permanent comment. A later page
  load renders any saved body as the comment (a saved line IS the answer, the
  0032 rule). The swap never happens while the input holds focus (DR20).
  Tests assert: blur saves without swapping; Enter swaps; reload renders the
  comment.
- Signed-out / device-only: the composer slot carries the 0032 hint line
  ("Sign in to keep your answer." — plain text, no link, no form, no cookie),
  with the prompt above it (the looking scaffold survives for strangers,
  DR6). **The old "post-answer silence" trigger died with the reveal event
  (DR8):** the hint now hides while the pinned details is open — pure CSS on
  the details' `[open]` + sibling selector (pin-first DOM order makes the
  selector possible), no JS. A hint under an open note is the nag 0032
  refused; same rule, new mechanism.
- "5 kept" text gone; keep glyph and its fill/aria-pressed behavior unchanged.
  **The teaching gap is confronted, not just logged (DR17):** DESIGN.md calls
  the count "the one thing telling a first-time reader what the glyph beside
  it does," and 0020 made walled surfaces mark-only BECAUSE `/` taught glyph
  literacy first. After this, no surface teaches with words. Accepted with
  eyes open: accessible names stay full-strength on every glyph; Keep's fill
  self-demonstrates on first tap; the bubble's wrong Instagram reading
  ("other people's comments") is bounded by what it opens — one tap shows two
  voices and no crowd. The decisions entry carries this argument; if the
  dogfood week shows the bubble read as social, the tripwire is DR12's ledger
  retreat, not a label.
- **Wordless day (DR5 — an explicit 0032 owner direction, carried):** a day
  with no note renders **no bubble, no thread, no pinned comment, no
  prompt** — the page degrades to picture + credit, exactly as 0032 shipped
  it (commit 580e5b4: a gate on nothing makes the invitation a lie; a thread
  with no words is the same lie in new clothes). The credit line therefore
  keeps a **standalone rendering path** outside the pinned body for exactly
  this branch — the first draft moved it into the pin's meta row and orphaned
  it on note-less days. Tested.
- Zoom, share, plate, masthead, coda: untouched.

## Cache line — carried, not renegotiated

`/` stays `public`, byte-identical, zero `Set-Cookie`. Bubble, thread shell,
pinned comment: cached markup identical for everyone. Toggle + fold:
client-side. Reader's comment/composer: the existing per-visitor
`impression_<id>` frame. `public_cache_headers_test.rb` holds the line; one
assertion updates (gate markup → thread markup present in the anonymous render).

**The prompt moves INSIDE the frame (DR6 — fixes a contradiction the first
draft shipped with).** The draft cached the prompt on the public page AND
promised "no prompt text anywhere in the answered DOM" — impossible without a
paint-then-vanish flash on every answered open, the exact invariant this
product bans. So: the frame renders the prompt in its composer branch (the
field's label) AND its signed-out-hint branch (the looking scaffold survives
for strangers), and omits it in the answered branch. XOR holds by
construction, zero flash, zero node surgery. Cost: the prompt arrives with the
frame's fade instead of first paint — the same trade the 0032 redesign already
made for the field. Bonus (DR19, wording corrected by eng OV10): `aria-describedby="sit-prompt"`
on the plate stays in the cached page untouched — pre-frame and post-answer
the id resolves to nothing and the description computes empty (alt text
carries); composer and hint states resolve to the prompt. That DEFAULT chain
needs no JS. The one JS half that remains is the pin-open handoff:
`sit_controller` swaps the plate's describedby to `daily-note` when the
pinned details opens (today's `sit_controller.js:50` mechanism, retargeted) —
never statically, which would flatten the collapsed note into the description
(the 0032 OV5 bug).

## No-JS floor

- Pinned fold is a native `<details class="cmt__pin">` — summary is the header
  row; opens without JS. (0032's floor, relocated.)
- Conversation section is server-rendered **open**, so a no-JS reader sees
  everything; the bubble is pure enhancement and does nothing without JS —
  acceptable because its only job is hiding.
- Invariant kept from 0032: nothing paints open and then folds. Default-open
  section + default-closed details are both the server-rendered state; the
  only pre-paint script is the day-scoped "reader closed the thread" check
  (mirror of the 0032 same-day-reveal script, same inline pre-paint idiom).

## Steps

**0. `/plan-design-review` — RUN 2026-09-01, decisions folded throughout.**
   Owner's standing review delegation applied (auto-select + record). Mockup
   generation skipped with a named reason: the owner-approved clickable
   prototype (three iterated rounds, variant C picked on the board) IS the
   visual contract; generated mockups from text briefs would compete with it
   and cannot be judged against this system's exact tokens (0032 precedent).
   Outside voice: Codex quota-dead until Sep 27 (verified this run); Claude
   design subagent ran independently, single-model, 23 findings — folded as
   DR1–DR22 below and inline above. The named questions, resolved:
   - **D-Q1 → "Tondo", monogram "T".** The word already lives in the masthead;
     the mark stays outside the app (DESIGN.md brand rule untouched — a letter
     is not the rose).
   - **D-Q2 → bubble everywhere the rail is; archive/preview thread open,
     pinned comment EXPANDED by default** (browsing posture, 0032 D7's
     spirit); archive shows the reader's dated comment if one exists, never a
     composer (capture stays a front-door ritual); preview keeps zero personal
     machinery.
   - **D-Q3 → medallions ship, as specced in the inventory (DR12)** — the
     owner picked variant C with them on the board; the recorded retreat is
     the ledger layer-swap, and the rule 6 amendment lands in step 5 BEFORE
     implementation.
   - **E-Q1 → resolved by DR6/DR19 with zero JS** (see Cache line): the
     prompt id lives inside the frame; absent states compute an empty
     description; the `daily-note` handoff happens only when the pinned
     details opens.
   - **E-Q2 → out of scope, noted — but its real half is in scope (DR18):**
     the story's ≥ 30% expansion denominator is *opens with the thread
     visible*, which the `shown` beacon gives by construction (it fires only
     when `.conv` is visible at connect). A closed-thread reader can't expand
     what's hidden; the metric must not punish the bubble for existing.

**1. The thread shell, with its tests.**
   - `daily/_day.html.erb`: bubble button in the rail (SVG per prototype,
     stroke 1.4, between zoom/share and the keep frame); conversation wrapper
     `<div class="conv" id="conv">` replacing the `<details class="sit">`
     block; `sit_controller` reworked in place (keeps its name, beacon wiring,
     and frame-src assignment): toggle action, aria swap, day-scoped
     closed-memory.
   - **localStorage keys are NEW names, never `sit` re-meant (eng E2).** 0032
     wrote `sit = <date>` meaning "revealed today"; re-meaning it as "closed
     today" would close the thread on deploy day for exactly the readers who
     used the gate that morning. Three keys, each owning one fact, all
     served-date-valued: `conv` = closed-on-this-date (DR3 memory),
     `shown` = shown-beacon-sent-this-date, `pin` = completed-beacon-sent-
     this-date (OV4). The old `sit` key is abandoned residue — never read,
     never migrated.
   - **Steps 1 and 2 are ONE deployable unit (OV7).** Step 1 deletes the
     details that houses the note; the pinned comment that re-houses it is
     step 2. Shipped alone, step 1 bares the note (write-first dead) and
     leaves `completed` with no trigger. The layering claim in "Shape of the
     change" is corrected: 1+2 land together; 3 and 4 may trail.
   - Pre-paint inline script: if closed-today, add `conv--closed` before first
     paint (0031/0032 idiom, idempotent on Turbo restore). **Turbo restore is
     not-a-load (DR9), by decision:** a Back-restored snapshot may show the
     pinned details open — accepted; the script recomputes only the day-scoped
     conv state (so a stale `conv--closed` cannot cross midnight). Back-path
     tested.
   - Hidden means hidden (DR20): the closed state uses `hidden`/`display:none`
     so the thread leaves the tab order entirely; the bubble is a real button,
     so focus stays on it after a close — asserted, not assumed.
   - `.conv` contains pinned comment + impression slot ONLY; coda outside
     (DR2). Frame `src` is assigned by `sit_controller` at connect, once
     (DR10 — 0032 assigned it at reveal; the reveal event is gone). During
     the fetch the thread shows the pin row alone — quiet, and the composer
     arrives on the existing rule 7 fade.
   - CSS: `.conv` block, `.rail` unchanged geometry; delete `.sit__details`,
     `.sit__summary`, `.sit--revealed` rules. All fades honor
     `prefers-reduced-motion` (instant), as every 0032 fade already does.
   - Tests (system + integration): bubble toggles + aria-expanded; default
     open; close → reload same day → closed; new-day reopen (travel or seeded
     storage); focus on bubble after close; coda visible while closed; cache
     headers + anonymous render carries thread markup; rail order asserted
     (bubble before keep frame); wordless-day branch — no bubble, no thread,
     credit standalone (DR5).

**2. The pinned comment, with its tests.**
   - `daily/_note.html.erb` reshapes into the pinned comment: medallion,
     `<details class="cmt__pin">` with summary header row (pin glyph, voice
     name, chevron), body = existing note branches (hand-written
     `simple_format` / museum clamp + More + source) + `label__credit`
     relocated as the meta row — EXCEPT the wordless branch, where credit
     renders standalone (DR5). `expand_controller`'s toggle re-measure (0032
     OV4) now listens on THIS details — verify, don't assume.
   - Summary row states its own bar: `min-height: var(--tap)` on the summary
     itself (rule 9, ISSUE-002 precedent — the old `.sit__summary` did; the
     new class does not inherit discipline, DR21). Pin glyph, chevron, and
     medallion all `aria-hidden` — the announcement is "Pinned · Cleveland
     Museum of Art, collapsed" and native details provides the state word; no
     redundant aria. Long museum names ("Art Institute of Chicago" at 375px +
     Dynamic Type) WRAP — never truncate an attribution in the story that
     exists to fix attribution (rule 3's spirit).
   - Voice name per D-Q1 ("Tondo"/"T"); museum days use
     `painting.source_name` and the source's initial.
   - **Beacon re-base, both sides on the same dedupe basis (OV4/OV5).**
     `shown` = "the thread was seen today": fires once per client per day
     (key `shown`), on connect-with-thread-visible OR on bubble-open — a
     reader who closed yesterday and reopens today still enters the
     denominator before they can enter the numerator. `completed` = "the
     pin was expanded today": once per client per day (key `pin`), on the
     details' first open. Numerator ⊆ denominator by construction; the
     ratio reads "fraction of daily lookers who opened the note." Beacons
     stay front-door only (archive/preview mount no sit_controller). One-line
     comment in the beacon controller renames what the columns mean from
     this date forward; `decisions/` entry carries it (step 5).
   - Tests: collapsed by default on every load (including same-day revisit —
     expansion never persisted); expand → note + credit visible, chevron/aria
     state; no-JS (details opens without Stimulus); museum-fallback More works
     after expansion; describedby handoff per E-Q1 asserted both states;
     beacon fires once per day per expansion.

**3. The reader's comment, with its tests.**
   - `impressions/_control.html.erb`: answered branch renders the run-in
     comment (medallion, weight-500 `<span>` name, answer text, `<time>` meta
     per DR22); composer branch gains the prompt as its own child (DR6) and
     otherwise IS the pre-answer state at page open (0032 already did this);
     revealed/after=reveal plumbing simplifies — the XOR is
     by-answer-presence, not by-reveal-event.
   - **Commit semantics v2 (eng review OV1/OV2 — supersedes DR4's half-fix;
     amends decisions/0022's D6 line again).** DR4 stopped the live blur-
     freeze and then reinstated it one load later ("any saved body renders as
     the comment") — on mobile the common path is type-then-tap-away, so most
     "commits" would have been accidents. The ink boundary moves to where the
     reveal's death left it pointing all along: **the day's end.**
     - Today's pick, signed-in: a saved body renders as the comment, and
       **tapping your own comment returns it to the composer, prefilled** —
       draft all day, deliberate or not, always recoverable.
     - Enter still transitions composer → comment in place (the "set it
       down" gesture keeps its meaning); blur/debounce save silently.
     - **Emptied field + Enter deletes the row** (server accepts blank as
       delete-my-answer; `Impression` presence validation scoped to real
       saves). A reader who typed, thought better, and erased is not
       published against their will (OV2).
     - A pick whose day has passed renders read-only — the archive shows
       ink, never a composer. "The notebook is ink" survives with the page
       turn as the binding, not the blur.
   - **Enter's three paths, specified (OV8):** dirty → await the save, then
     `frame.reload()` (sequenced, so the reload never races the write);
     clean (`body === saved`) → skip the save, reload directly — the
     early-return at `autosave_controller.js:49` must not make Enter a dead
     key; save failed → no swap, composer keeps the text, whisper stays
     silent (calm degradation, tested).
   - The `after=reveal` param and `revealed:` local die; `#control` branches
     on impression-presence + pick-day only. Enter's commit is
     `frame.reload()` — no new URL, no new event vocabulary.
   - Prompt XOR reply asserted: no prompt text anywhere in the answered DOM —
     server-rendered per branch, so the assertion is against the frame
     response, not against a JS deletion. (Tap-to-edit re-renders the
     composer, which brings the prompt back as its label — the XOR is
     per-state, and editing is the composer state.)
   - **The archive answer arrives by frame variant, not inline (eng E1 as
     corrected by OV3).** First draft said render it server-side inline;
     `days_controller.rb` answers `stale?(etag: [@pick, @pick.painting])`
     under `private_revalidate` with no identity in the key — user A's
     comment in the cached body + user B's matching ETag = a 304 serving A's
     words to B on a shared browser. So the cached-body pages stay
     identity-free everywhere: archive (and only archive) renders the frame
     WITH a server-side `src` carrying `view=answer` — `#control` answers
     the impression read-only or nothing, never a composer, never a hint,
     under the existing `no_store`. Preview renders no frame at all.
   - Signed-out hint row (with prompt above it, hint hidden while the pin is
     open — DR8); device-only empty — both re-asserted in the new layout
     (0032's privacy-order table still binding).
   - Tests: composer state; type + blur → SAVED, still a composer; Enter
     dirty/clean/failed (all three OV8 paths); tap comment → prefilled
     composer; empty + Enter → row gone, composer stays; reload same day →
     comment; yesterday's pick → read-only, no tap-to-edit; archive frame
     `view=answer` never renders a form and its ETag-free no-store headers
     asserted; signed-out hint hides under an open pin; device rows;
     dynamic-type fold-budget assertions re-pointed at the pin header row.

**4. Keep-count removal, with its tests.**
   - `favorites/_control.html.erb`: delete the `count`-guard block and the
     `count:` local threading. With the count gone the `compact:` split loses
     its only difference, so the whole apparatus dies with it (eng E5):
     the hidden `compact` field, `params[:compact]` handling and the
     `collection.count` computation in `favorites_controller.rb:171-187` —
     one COUNT query removed from every keep render and write.
   - `favorites_test.rb` + system assertions on "N kept" updated/removed.
   - This reverses the 2026-08-19 narrowing of `decisions/0010` (count-as-
     reward on `/` and `/days/:date`) — named in the step-5 decisions entry,
     not silently.

**5. Bookkeeping, same unit of work (R1/R4/D-Q3).**
   - `decisions/00XX-the-thread-replaces-the-gate.md`: direction change (gate
     → thread), pinned-fold write-first argument, **0032 F1's retirement by
     name (DR1)**, keep-count reversal **with the teaching-gap argument
     (DR17)**, the closed-polarity trade + tripwire (DR3), beacon re-base
     with the DR18/OV5 same-dedupe metric, the D6 ink-boundary amendment
     (blur → reveal → **day's end**; OV1), and the story's falsifiable
     prediction as amended below. Three honesty clauses the eng review owes
     this entry (OV6/OV9):
     - **0032's ≥ 20% prediction is retired UNFALSIFIED** — its measuring
       mechanism (the reveal event) is deleted the day 0032 reached
       production, with zero days of reader data. Recorded as
       abandoned-unmeasured, not quietly overwritten.
     - **What the new metric blesses, said out loud:** success at 30% means
       most opens never read the hand-written note — the product's stated
       moat. Stance: the moat is that the words exist, are attributed, and
       cost one visible tap; reading is an invitation, not an obligation.
       If that stance is wrong, the metric will say so.
     - **Revert, costed honestly:** "one layer swap" is true only of the
       medallion→ledger retreat. Reverting the thread itself is a
       multi-file restore (views, CSS, sit_controller, localStorage keys)
       plus a second mid-table beacon meaning flip. Named so the Sep kill
       review reads the number knowing the exit price.
   - `DESIGN.md`, all in this unit of work because after ship the current text
     is FALSE and this file warns that a rule nothing obeys teaches readers to
     distrust it:
     - `.conv`/`.cmt` component entry: medallion spec (DR12), run-in name at
       weight 500 (DR11), "Pinned" as words not chip (DR14), time vocabulary
       (DR22).
     - Rule 6 amendment: identity medallions — drawn on `--bg-lift` with a
       hairline edge, never a gold fill; the 0017 filled-tile tripwire
       untouched.
     - `.sit` entry rewritten (the gate it describes is gone); the "chevron
       is an idiom this product has never shown" sentence amended — the pinned
       fold shows one now, deliberately, two static orientations, no motion
       (DR13).
     - `.rail` section: "Zoom, then Keep, then the count" and BOTH
       count paragraphs updated (DR17) — bubble joins the roster, count
       leaves, fill-for-state noted as the rail's one state grammar (DR15).
     - Rule 8 re-amendment ("shown whole once the pinned comment is
       expanded").
   - Story's owed item carried: 0032 prompt copy pass remains open, unchanged
     by this story.

**6. `bin/ci` green → `/qa` → `/simplify` → `/code-review` → re-verify →
   ship** — steps 5–9 of the standing flow. Deploy note: this rides web-only;
   no shell/TestFlight dependency.

## Design review (2026-09-01) — settled, cite don't reopen

Single-model outside voice (Claude design subagent; Codex quota-dead until
Sep 27). 23 findings; every one resolved above or here. The DR numbers used
throughout map to the subagent's F numbers 1:1. Two subagent recommendations
were REJECTED because they reversed explicit owner directions, recorded per
R9:

- **F7 (keep the prompt as a caption on the answered comment) — rejected.**
  The owner's direction is literal: "once user has answered, we don't need to
  show the prompt." XOR stands; DR6 dissolves the cache contradiction the
  subagent used as half the argument. Cost accepted with eyes open: an
  archive re-encounter shows an answer without its question; prompts rotate.
  If dogfooding shows answers reading as nonsense out of context, the
  pre-agreed fix is the prompt in the comment's `<time>`-row as dim meta —
  one line, owner's call, not a silent revert.
- **F12's headline (ship the ledger, drop medallions) — rejected.** The owner
  picked variant C with medallions on the comparison board. Everything else
  in F12 was adopted: the exact medallion spec is transcribed, the fill is
  linen-lift not gold, the ledger is the built-in retreat layer.

## Risks / open questions beyond the review questions

- **Instagram grammar vs museum voice.** The run-in name and medallions pull
  toward feed vernacular on the calmest page in the product. The board chose C
  knowingly; the tripwire is the pre-live dogfood week — if the page reads as
  social chrome rather than attribution, the ledger variant (A) is the
  pre-chosen retreat, one CSS layer removal (DR12/DR16 build order).
- **Beacon continuity.** `completed` changes meaning mid-table (reveal →
  pinned expansion). Per-date rows make the discontinuity legible; the
  decisions entry dates it.
- **Two folds on the closed path (DR18).** A reader who closed the thread
  pays bubble + pin to reach the note — two taps, two affordance grammars.
  Accepted for the default-open path; the metric denominator excludes them by
  construction.
- **App Review optics** unchanged from 0032 (note behind one visible tap;
  artwork never hidden).

## Eng review (2026-09-01) — settled, cite don't reopen

Step 0 scope: complexity check tripped (>8 files) and was auto-decided
PROCEED per the owner's standing delegation — no new classes, no migration;
the file count is the inherent surface of a view+CSS+controller rework plus
a user-directed removal. Search check: details/turbo-frame idioms are
Layer 1; no web search needed. Primary findings E1–E5 (verified against
source), outside voice OV1–OV11 (Claude subagent, single-model — Codex
quota-dead until Sep 27). Everything folded above; the map:

- **E1 → corrected by OV3.** Archive answer via `view=answer` frame variant,
  never inline in the ETag'd body (`days_controller.rb:43-45` has no
  identity in the key — a 304 would serve one reader's words to another).
- **E2 (+OV4).** New localStorage names `conv`/`shown`/`pin`; `sit` is
  abandoned residue (deploy-day semantic collision otherwise).
- **E3 → superseded by OV1/OV8.** Enter = await-save-then-`frame.reload()`,
  three paths specified; ink boundary = day's end; tap-to-edit same day;
  blank + Enter deletes (OV2).
- **E4.** `expand_controller.js:17` binds `closest("details")` — already
  generic over the new `.cmt__pin`; verified, no change needed.
- **E5.** Favorites `compact`/count apparatus dies whole
  (`favorites_controller.rb:171-187`); one COUNT query saved per keep
  render/write.
- **OV5.** Metric re-based: both beacons once-per-client-per-day, numerator
  ⊆ denominator; the 0032-baseline comparison is deleted from the story
  (baseline never existed — 0032 reached readers for zero days).
- **OV6/OV9.** Honesty clauses in the decisions entry (0032 prediction
  retired unfalsified; revert costed truthfully; what 30% blesses).
- **OV7.** Steps 1+2 one deployable unit.
- **OV10.** DR19's zero-JS claim scoped to the default chain; pin-open
  handoff is sit_controller JS, as today.
- **OV11.** Duplicate Risks section deleted.

## Coverage map and failure modes (eng review)

```
CODE PATHS                                          USER FLOWS
[+] sit_controller.js (reworked)                    [+] The thread (system tests)
  ├── connect: conv visible → shown beacon (dedup)    ├── open → thread open, pin folded, composer waits
  ├── connect: conv--closed → no beacon               ├── tap pin → note + credit + More; describedby → daily-note
  ├── bubble toggle → aria, hide/show, conv key       ├── tap bubble ×2 → closed, coda still visible, focus on bubble
  ├── bubble reopen → shown beacon (same-day dedup)   ├── close → reload → still closed; tomorrow → open (travel)
  ├── pin toggle open → completed beacon (dedup)      ├── type → blur → SAVED, still composer
  ├── frame src at connect, once                      ├── type → Enter → own comment, prompt gone
  └── pre-paint script: conv key only, Turbo restore  ├── tap own comment → prefilled composer (today only)
[+] impressions#control (simplified)                  ├── empty + Enter → row deleted, composer stays
  ├── impression + past day → read-only comment       ├── revisit next day → comment is ink, no tap-to-edit
  ├── impression + today → comment, tap-to-edit       ├── archive day with old answer → dated read-only comment
  ├── user, no impression → composer + prompt         └── wordless day → no bubble, no thread, credit standalone
  ├── anonymous → prompt + hint (no link/form/cookie)[+] Error states
  ├── device-only → empty frame                       ├── Enter save fails → composer keeps text, no swap, silent
  └── view=answer → comment or NOTHING, never a form  ├── frame fetch fails → pin row alone (0032 posture)
[+] impressions#create                                └── storage blocked → thread opens daily, beacons re-fire
  ├── blank body + commit → destroy row                   (over-count recorded, identical to 0032's stance)
  ├── blank body autosave → early-return client-side
  └── device POST → :forbidden (unchanged)
[+] favorites: no count, no compact — glyph-only both callers
[+] cache: / public + ETag + zero Set-Cookie; #control no_store;
    archive body identity-free (view=answer frame carries the answer)
```

Every path lands as a Minitest/Capybara test in its step. **Failure modes:**
half-draft published by accident (OV1 — killed by tap-to-edit + day-end ink);
deleted text resurrected (OV2 — blank-delete + tested); cross-user 304 on
archive (OV3 — variant frame, headers asserted); Enter dead-key after
debounce (OV8 — clean-path reload, tested); deploy-day thread lockout (E2 —
new key names); beacon double-count on storage-blocked clients (accepted,
recorded — same stance 0032 shipped with). No silent critical gaps remain.

**Parallelization:** steps 1+2 are one lane (same templates, one deploy
unit); step 3 touches only the impressions partial/controller and could run
parallel, but it meets 1+2 in `_day.html.erb`'s frame and the system suite —
sequential recommended (solo, WIP = 1). Step 4 is independent and trivially
parallel; not worth a worktree.

**NOT in scope (eng):** rate limiting on beacons (0032's accepted spoofable
tally, unchanged); a `committed_at` column (day-end boundary needs no
schema); unbundling the three owner-directed changes into separate stories
(each has its own tripwire; one revert claim covers the set, priced above);
TODOS routing (this repo triages via `IDEAS.md`; nothing new queued —
the OV6 unbundling concern is recorded here, deliberately not pursued).

**What already exists and is reused:** the walled two-caller frame idiom
(Keep's architecture, 0032's controller); autosave whole; `expand_controller`
untouched (E4); native details + pre-paint script idiom (0031/0032); beacon
endpoints and `sit_counters` table (columns re-meant, not re-made); the
`chrome:` local divergence for archive/preview posture.

## Implementation tasks

- [x] **T1 (P1)** — thread shell: bubble (gold/fill states DR15), conv
  wrapper + boundaries (DR2), sit_controller rework, new `conv`/`shown`/`pin`
  keys (E2/OV4), day-scoped closed memory + polarity tripwire (DR3), frame
  src at connect (DR10), focus/hidden discipline (DR20), wordless-day branch
  (DR5), CSS, tests (step 1 — deployed with T2, OV7)
- [x] **T2 (P1)** — pinned comment: details fold, 44px summary bar +
  aria-hidden glyphs + wrapping names (DR21), voice name (D-Q1),
  credit-as-meta with standalone wordless path (DR5), chevron static swap
  (DR13), same-dedupe beacon re-base (OV4/OV5), tests (step 2)
- [x] **T3 (P1)** — reader's comment: prompt-in-frame XOR (DR6/DR19+OV10),
  day-end ink + tap-to-edit + blank-delete (OV1/OV2), Enter's three paths
  (OV8), `view=answer` archive variant (E1/OV3), weight-500 name span
  (DR11), `<time>` meta (DR22), hint-under-open-pin CSS (DR8), privacy rows,
  tests (step 3)
- [x] **T4 (P2)** — keep-count removal: partial + controller compact/count
  apparatus (E5) + decisions/0010 reversal with teaching-gap argument (DR17)
  (step 4)
- [x] **T5 (P1)** — decisions entry (`decisions/0023`) + all five DESIGN.md
  updates (step 5)
- [ ] **T6 (P1)** — owner copy pass: voice name, bubble aria labels, hint
  line — reviewed field by field before ship. **Owed, named not hidden:**
  the reader's own medallion monogram ("Y") was an implement-time filler
  choice, never specified by design review — first thing to confirm or
  change in the copy pass.

## Deviations (implement-time)

- **`tag.details` required, not raw attribute interpolation.** The first
  draft built `.cmt__pin`'s conditional `data-action` by interpolating a
  whole `data-action="toggle->sit#pinToggled"` string into the tag. ERB's
  `<%= %>` HTML-escapes that interpolation, turning the embedded quotes
  into `&quot;`/`&gt;` and corrupting the attribute value — Stimulus never
  bound the action, so the describedby handoff (DR19) silently never fired.
  Found by `bin/rails test:system` (`sit_test.rb`'s pin-open assertions).
  Fixed with `tag.details(..., data: pin_data) do ... end`, which builds
  the attribute programmatically and escapes correctly by construction.
- **`daily/_note` must render unconditionally, not gated on `has_words` at
  the call site (DR5, corrected).** The first draft wrapped the ENTIRE
  `.conv` structure — including the call to `daily/_note` — in
  `if has_words`, which meant the partial's own wordless-day standalone-
  credit branch was dead code: it was never invoked on the one day it
  exists for. Fixed in `daily/_day.html.erb`: `daily/_note` always renders;
  only the `.conv` WRAPPER (bubble, reader's slot) is gated on `has_words`.
- **`.label__source` retired, not carried forward.** The pin's own "Pinned ·
  <voice>" summary now says what `.label__source`'s "From <museum>" sentence
  used to say — keeping both would have been the SAME attribution twice.
  Removed the dead CSS rule and updated the two `daily_test.rb` assertions
  that checked for it to check the pin's summary text instead.
  `test/integration/daily_test.rb`.
- **`.cmt + .cmt` never matched a single element.** The two `.cmt` rows
  (pinned comment, reader's slot) are never adjacent siblings — the
  reader's slot is always wrapped in a `<turbo-frame>`, which sits between
  them in the DOM. The rule was dead from the first draft (0px gap,
  unnoticed until fold-budget measurement). Fixed with an explicit
  `.cmt-frame` class on both impression `turbo_frame_tag` calls
  (`display: block`) and `.cmt + .cmt-frame` instead.
- **`.cmt__fold`'s `display: flex` returns computed `line-height: normal`
  as the literal string, not a pixel value, in Chrome.** `parseFloat("normal")`
  is `NaN`, which serializes to `nil` across the Capybara JS bridge — the
  proximate cause of four `dynamic_type_test.rb` errors
  (`TypeError: nil can't be coerced into Float`). Block-level siblings
  (`.label__note p`, `.label__text`) never hit this because they always
  carry an explicit `line-height`. Fixed by giving `.cmt__fold` one too
  (`1.5`) — the general lesson (flex containers don't reliably resolve
  `line-height: normal` to px) is now the file's own comment at that rule.
- **`--pin-reserve: 15px` added to the plate's height cap, not the full
  `--tap` (44px) the pin row actually measures.** The pin row is one more
  fixed-height touch target before the front door's first written line —
  architecturally the same shape as `--rail-reserve` — but a full 44px
  reserve pushed the accessibility-cap shrink to 28% against
  `dynamic_type_test.rb`'s own 25% ceiling (`test_the_plate_never_grows...`).
  15px is the largest reserve solvable from that test's own inequality that
  still clears it; `.label__meta:has(+ .conv) { margin-bottom: 0.5rem }`
  carries the remainder of the fold-budget gap the reserve alone doesn't
  close. Both scoped to a server-rendered `.page--thread` class, never to
  `.cmt__pin[open]` — a `:has()` keyed to the pin's own open/closed state
  would resize the ARTWORK live every time a reader toggled the note.
  `dynamic_type_test.rb`'s hardcoded plate-height expectation at 375×667
  updated 319 → 304 to match the new, deliberate formula.
- **The prompt's move inside the frame (DR6) turned two fold-budget system
  tests into races.** `daily_test.rb` and (transitively, via the shared
  `fold()` helper) `dynamic_type_test.rb` measured `.sit__prompt`'s position
  immediately after `visit root_path`, which was correct under 0032 (the
  prompt was server-rendered, present at first paint) but races
  `sit_controller`'s frame fetch under 0033. Fixed with an explicit
  `assert_selector ".sit__prompt", wait: 3` before measuring in
  `daily_test.rb`; `dynamic_type_test.rb`'s signed-in tests were unaffected
  since `fold()` now prioritizes `.cmt__fold` (always server-rendered,
  never framed) over `.sit__prompt` in document order.
- **CRITICAL, found by `/qa` against a live dev server, never by the
  suite: every real save 422'd.** `autosave_controller.js`'s `write()`
  switched from `FormData(this.element)` (the ORIGINAL 0032 code, where
  `this.element` was the `<form>`) to `new URLSearchParams({ body })` when
  the controller's mount point moved to the persistent frame for the
  tap-to-edit rework — and dropped the CSRF token that came free with
  `FormData` in the process. Invisible to `bin/rails test`/`test:system`
  because `config/environments/test.rb` disables forgery protection for
  the whole suite (the same blind spot `sit_beacon_test.rb`'s own
  `with_forgery_protection` test exists to close for the beacon). `/`
  carries no CSRF meta tag by design (story 0007 — one would write a
  session onto the publicly cached page), so the fix reads the token from
  the composer's own `<form>` — which DOES still get one, since it is
  rendered inside the walled, `no_store` frame response, not the public
  page. Fixed in `write()`/`flush()`; regression test added —
  `test/system/sit_test.rb`, "the answer saves with forgery protection
  genuinely on" — verified to fail without the fix (reverted the file,
  confirmed red, restored it, confirmed green) before being kept.

## Code review (2026-09-01) — 15 findings triaged

Fixed:
- **`aria-controls="conv"` pointed at nothing.** `.conv`'s server markup
  only ever carried `class`/`data-sit-target`, never `id="conv"` — a
  genuinely broken ARIA relationship since the bubble first rendered.
  Added `id="conv"` in `daily/_day.html.erb`.
- **`autosave_controller`'s `this.saved` never resynced across a frame
  swap.** `connect()` fires once, on mount — never again on the
  composer↔comment content swaps Turbo does inside the same persistent
  frame. Tap-to-edit's prefill left `this.saved` stale (`undefined`),
  so an unchanged Enter read as dirty: a wasted write, and on a failed
  one, a composer stuck open instead of returning to the comment. Fixed
  by resyncing on `turbo:frame-load`, which fires on every swap.
  Regression test: `sit_test.rb`, "editing without changing anything
  reads as clean, not dirty" — reads `this.saved` straight off the live
  controller instance.
- **`save()` had no `hasInputTarget` guard; `flush()` did.** A debounce
  timer scheduled while the composer was up can still fire after Enter
  or edit swaps the frame's children out from under it. Matched
  `flush()`'s existing guard.
- **`find_by!` in the `RecordNotUnique` retry could still 500.** A third
  request deleting the row in the same instant as two racing autosaves
  is a real, if tiny, window. Swapped for `find_by` + nil-check.
- **`answered` computed independently in controller and view.** The
  controller derives it once for the prompt-query guard; the view
  re-derived the identical condition to pick its own branch — two
  copies of one fact, free to drift. Controller now passes `answered:`
  as a local; the view branches on it directly.
- **`impressions_controller.rb`'s header comment overclaimed
  enforcement.** It read as if the day-end boundary were checked on
  write, when `#create` is deliberately date-blind (eng Q2, carried
  from 0032) — only the READ side (`render_control`) is surface-gated.
  Reworded so a future reader can't infer a check that isn't there.
- **Pre-paint script duplicated `sit_controller#syncBubble` by hand.**
  The inline pre-paint script (fold state before Stimulus boots) also
  set the bubble's aria/fill attributes — a second copy of `syncBubble`
  with no mechanism keeping them in sync. Trimmed the inline script to
  only what `connect()` can't fix after the fact (the note's own
  `hidden`); `connect()`'s own `syncBubble()` call, moments later,
  owns the bubble state exclusively now.
- **`pinned_voice_initial` had no nil guard.** Reachable only by
  bypassing validation (`update_column`, a bad import row), but this
  renders on every front door — one bad row would 500 the whole page
  for every reader, not just that painting. Cheap guard added
  (`"?"` fallback); regression test in `application_helper_test.rb`.
- **`.cmt__meta`'s credit-line render had no test coverage.** Added an
  assertion to the existing museum-fallback pin test in `sit_test.rb`.

Considered and skipped (already-accepted trade-offs, re-litigated by
the review, not new bugs):
- **`aria-describedby="sit-prompt"` dangling once answered/before the
  frame resolves.** Exactly DR19/OV10's already-reviewed trade-off —
  the id resolves to nothing, the plate's alt text carries the
  description. Not a regression.
- **`--pin-reserve` not dropping to 0 when the bubble closes.** Fixing
  this would require keying the reserve to the bubble's live-toggled
  state, reintroducing the exact live-resize-on-interaction problem
  `--rail-reserve`/`--pin-reserve` were both built to avoid by staying
  keyed to the static `.page--thread` class instead. The cost (a
  slightly smaller plate while closed) is smaller than the cost of the
  fix.
- **Curator two-step edit (blank blurb, then blank description) can
  orphan an existing impression from view.** Admin-only, two-step,
  reversible (re-adding words restores visibility) — not worth the
  added branch in the `has_words` gate for a sequence a curator would
  have to construct deliberately.
- **"Y" avatar beside the anonymous sign-in hint.** Present since the
  first implementation, visually confirmed during `/qa`, and readable
  as "this is your slot" framing paired with the hint underneath.
  Real question, but a copy/design call, not a bug — left for T6's
  owner copy pass, which already owes a look at this exact medallion
  (plan note above).
- **`_time.html.erb`'s ternary vs. `days/_row_body.html.erb`.** Already
  aligned on format and date-comparison basis in `/simplify`; the
  remaining "duplication" is a one-line ternary using shared building
  blocks — extracting a helper for that would be the premature
  abstraction CLAUDE.md warns against.
- **Bubble SVG vs. `_keep_glyph.html.erb`'s fill-toggle shape.** Two
  genuinely different icon paths that happen to share the fill-is-
  state CSS idiom — not logic duplication. Forcing them into one
  parameterized partial for two call sites would be over-engineering.

`bin/ci` green after fixes (811 tests, 0 failures/errors; Brakeman clean).

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | quota-dead until Sep 27 (verified); Claude subagents substituted in both reviews, tagged [single-model] | design voice: 23 findings; eng voice: 11 findings |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAN (PLAN) | 16 issues (E1–E5, OV1–OV11), 0 critical gaps open |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN (FULL) | score: 6/10 → 9/10, 27 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CROSS-MODEL:** Single-model outside voices in both reviews (Codex
quota-dead). Design pass: 5 convergent, 18 net-new, 2 owner-direction
rejections recorded per R9. Eng pass: outside voice found three P1s the
primary pass missed or created — the reload-commit contradiction (OV1), the
no-edit/no-delete trap (OV2), and the archive ETag 304 leak introduced by
the primary pass's own E1 inline-render fix (OV3, corrected to a `view=answer`
frame variant). Load-bearing amendment: **the ink boundary moved to day's
end** (tap-to-edit same day, blank-delete, read-only after rollover) —
amends decisions/0022's D6 line a second time; flagged to the owner as the
one review decision touching a prior owner call.

**VERDICT:** DESIGN + ENG CLEARED — ready to implement. Steps 1+2 deploy as
one unit (OV7); `decisions/00XX` and the five DESIGN.md updates land during
implementation, before ship (T5).

NO UNRESOLVED DECISIONS
