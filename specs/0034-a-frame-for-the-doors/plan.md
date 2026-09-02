# 0034 — Implementation plan

Story: `story.md`. Decision: `decisions/0024-the-doors-get-a-frame.md`.
Mocks (approved): https://claude.ai/code/artifact/828cce6a-ed95-4ec3-a204-8d006fdfe241

## Scope check, stated plainly

This is CSS-only. Zero view/ERB changes, zero new classes on any element,
zero migration, zero controller change. `corners/show.html.erb`'s four
`button_to`/`link_to` calls already carry the exact class names this plan
restyles (`signin__out`, `account__delete`, `push__enable`, `push__disable`)
— confirmed by reading the view (unchanged since story 0017/0010) and by
`test/integration/corners_test.rb`, which asserts on `form[action=?]` and
`href=?`, never on these classes' visual rules. That's why the whole fix
lives in `app/assets/stylesheets/application.css:1506-1535` and nothing
else moves.

## The diff

Current (`application.css:1506-1535`):

```css
.signin__out,
.account__delete,
.push__enable,
.push__disable {
  min-height: 44px;
  display: inline-flex;
  align-items: center;
}
.signin__out-form,
.account__form,
.push__form { display: inline-flex; }
.signin__out,
.account__delete,
.push__disable {
  background: none;
  border: none;
  padding: 0;
  color: var(--gold);
  cursor: pointer;
}
.signin__out:hover,
.account__delete:hover,
.push__disable:hover { color: var(--gold-deep); }
```

Replaces with:

```css
/* Chip anatomy borrowed from .signin__door (decisions/0024): a safe variant
 * (gold on hairline, matching .signin__door exactly) and a destructive one
 * (--warn tint). `.push__enable` joins the styled group here for the first
 * time — it's an <a>, not a <button>, so it used to get color free from the
 * global `a` rule and nothing else: no box at all, the same gap as the two
 * buttons this reverses. */
.signin__out,
.account__delete,
.push__enable,
.push__disable {
  min-height: 44px;
  display: inline-flex;
  align-items: center;
  padding: 0 1.15rem;
  border-radius: 2px;
  cursor: pointer;
}
.signin__out-form,
.account__form,
.push__form { display: inline-flex; }

.signin__out,
.push__enable,
.push__disable {
  border: 1px solid var(--hairline);
  background: var(--bg-lift);
  color: var(--gold);
}
.signin__out:hover,
.push__enable:hover,
.push__disable:hover { border-color: var(--gold-deep); color: var(--gold-deep); }
.signin__out:active,
.push__enable:active,
.push__disable:active {
  background: rgba(125, 95, 24, 0.14);
  border-color: var(--gold-deep);
  color: var(--gold-deep);
}

/* Delete this device's data (`DevicesController#destroy`) shares this class
 * with Delete account on purpose — same irreversible-action weight, same
 * chip. */
.account__delete {
  border: 1px solid rgba(163, 63, 40, 0.4);
  background: rgba(163, 63, 40, 0.055);
  color: var(--warn);
}
.account__delete:hover { border-color: var(--warn); background: rgba(163, 63, 40, 0.09); }
.account__delete:active { background: rgba(163, 63, 40, 0.14); border-color: var(--warn); }
```

`:active` is the one addition beyond the mock: the mock showed default and
`:hover`, but this is primarily a touch product (WKWebView), where `:hover`
barely fires — the state that actually gives tap feedback is `:active`.
Shipping only a hover treatment would have left the exact complaint half-fixed
on the surface that matters most. Reuses the `--hairline`/`--warn` RGB bases
at higher opacity rather than introducing new colors.

`.legal .caps-link` (Privacy/Support) is untouched — not in this selector
list today, stays that way.

## Deliberately unchanged

- **Focus ring** stays the global `:focus-visible { outline: 2px solid
  var(--gold); ... }` for every chip, safe or destructive. A focus
  indicator's job is visibility, not semantic color-matching; a
  warn-colored ring buys nothing and is one more rule to keep in sync.
- **No `appearance: none` / UA reset added.** `.signin__door` sets none
  either and has shipped clean on both `<button>` and `<a>` since story
  0015 — the explicit `border`/`background` this plan adds already beats
  UA defaults; adding a reset nothing else in the file needed would be
  solving a problem that isn't there.
- **`font-family` untouched.** Neither the old rule nor `.signin__door`
  states one; whatever inheritance already renders `.signin__door` and the
  masthead/legal caps-links in the house serif keeps doing the same job
  here. Not this story's problem to solve twice.

## Test plan

No new Minitest coverage — there is no new branch, conditional, or markup
for a test to exercise; `corners_test.rb`'s existing 20 tests already pin
every class name this diff restyles (`assert_select "form[action=?]"`,
`href=?`) and stay green unchanged, which is itself the regression guard:
if any of them started failing, the diff would have touched more than CSS.

Real verification is visual, same as ISSUE-002 (the last time this exact
question was CSS-only): `/qa` against a real dev server, both `:account`
and `:device` states, confirming against the approved mock —
```
bin/rails test test/integration/corners_test.rb   # unchanged, green
bin/ci                                             # full suite, unchanged, green
```
then a live-browser pass: sign in (dev sign-in), open `/you`, compare Sign
out / Delete account / notification toggle against the mock; register a
device (no account), open `/you`, compare Delete device / notification
toggle against the mock; confirm Privacy/Support are still plain text in
both states.

**On-device check (flagged by eng review's outside voice):** `.push__enable`
is the one chip that's an `<a>`, not a `<button>` (the other three). WebKit
has a long-standing quirk where `:active` doesn't fire on a plain link
without an `onclick` handler or touch listener somewhere in its ancestor
chain — real on iOS Safari for over a decade, unconfirmed whether it still
reproduces on this app's iOS 17+ floor. Check on a real device during T3: if
`:active` doesn't visibly fire on tap for "Get the daily notification," the
resting chip (border + fill + gold, unaffected either way) still fixes the
reported bug — this would only mean one of four controls ships without press
feedback, not a regression. Fallback if confirmed missing: an empty
`onclick=""` on the link is the standard one-line fix, not applied
speculatively here since the bug isn't confirmed to exist on this floor.

## Deploy

Static asset only — ships on the next Rails deploy, no migration, no
backfill, additive-only by construction (nothing reads these rules at
request time; they're pure presentation). Safe to bundle with the next
deploy rather than needing its own.

## Non-goals (from story.md, restated for the record)

No third button weight, no change to `.signin__door`/compass/wings/legal/
rail glyphs, no copy change, no confirmation-dialog change.

## Accessibility — verified, not assumed

Computed WCAG relative-luminance contrast (sRGB formula) for every text/fill
pair this diff introduces:

| Pair | Ratio | AA (4.5:1) |
|---|---|---|
| `--gold` on `--bg-lift` (safe chip, resting) | 4.76:1 | pass |
| `--gold` on `--bg` (existing `.signin__door`, unchanged) | 5.21:1 | pass |
| `--warn` on the warm tint (destructive chip, `--warn` at 5.5% opacity actually composited onto `--bg`, not eyeballed) | 5.14:1 | pass |

All three clear AA with margin; none is a new color, both tokens already
ship elsewhere in the product. 44px tap target carried over unchanged from
the current rule (DESIGN.md rule 9). Keyboard/focus: unchanged global
`:focus-visible` outline, native `<button>`/`<a>` tab order — nothing new to
specify. Screen reader: button text is already descriptive ("Sign out",
"Delete account") with no icon-only ambiguity — no ARIA change needed.

*(Correction from eng review's outside voice: the first draft computed
5.56:1 by testing `--warn` against plain `--bg`, not against the actual
low-opacity composited tint — the real blend is slightly lighter. 5.14:1 is
the correct number; still clears AA with margin, so nothing about the ship
decision changes, but the number itself was wrong and is fixed here.)*

## DESIGN.md amendment

Rule 6 already permits everything this diff does ("no rounded corners
beyond the 2px on form controls" — `.signin__door` has shipped exactly that
shape since story 0015), so no rule changes meaning. It does not yet name
that a second chip variant exists. One line added to Rule 6 for the next
reader:

> **Two chip weights, not one.** `.signin__door`'s anatomy (hairline
> border, `--bg-lift` fill, 2px radius) now has a destructive sibling —
> `--warn`-tinted border and fill, same shape — for actions that cannot be
> undone. `decisions/0024-the-doors-get-a-frame.md`.

## NOT in scope (considered, deferred)

- **A third, higher-emphasis chip weight** (e.g., for a future primary CTA)
  — nothing in the product needs one yet; inventing it now is exactly the
  "infrastructure for later" CLAUDE.md names as a failure pattern.
- **Confirmation-dialog redesign** for the two destructive actions —
  `turbo_confirm`'s native browser dialog is unchanged; the resting button
  is what this story is about.
- **Extending the chip treatment to `.legal`** (Privacy/Support) — deliberately
  kept as plain text; they are navigation, not action, and the story's whole
  point is making that distinction visible, not erasing it.
- **A DESIGN.md rule renumbering or restructure** — one line added to Rule
  6, nothing reorganized.

## What already exists (reused, not reinvented)

- `.signin__door` chip anatomy (`application.css`, story 0015) — the entire
  safe-variant shape is this, unchanged.
- `--gold`/`--gold-deep`/`--warn`/`--hairline`/`--bg-lift` — all five colors
  already in `:root`; zero new tokens.
- `--tap` (44px) — DESIGN.md rule 9's existing tap-target registry; these
  four classes already belonged to it and keep their membership unchanged.
- The global `:focus-visible` rule — reused as-is.

## Implementation tasks

- [ ] **T1** — Replace the flat-reset block with the two-variant chip CSS
  above (`application.css:1506-1535`).
- [ ] **T2** — Add the one-line Rule 6 amendment to `DESIGN.md`.
- [ ] **T3** — Live-browser QA against the approved mock, both `/you`
  states (plan's Test plan section).
- [ ] **T4** — `bin/ci` green (no test changes expected; this is the
  regression guard).

## Unresolved decisions

None. The one open item from the first draft (destructive-tint opacity) is
resolved above rather than deferred — owner delegated review decisions this
session.

## GSTACK REVIEW REPORT

### Design review (7-pass)

Single-file CSS diff, no view/controller/model change. Owner delegated all
decisions this session — findings folded directly into the plan rather than
gated behind individual approvals.

| Pass | Before | After | Notes |
|---|---|---|---|
| 1. Information architecture | 10/10 | 10/10 | Zero new/moved/removed elements; hierarchy untouched by construction. |
| 2. Interaction state coverage | 5/10 | 9/10 | Hover-only was a real gap on a touch-first product — added `:active` press feedback (safe + destructive). Disabled/loading states not applicable (no async submit UI on these controls). |
| 3. User journey & emotional arc | 8/10 | 8/10 | Scope is one control's resting appearance; the arc this fixes (hesitation → confidence) is already the story's stated success signal. |
| 4. AI slop / hard rules | 9/10 | 9/10 | APP UI classification. Clean against the blacklist — no gradients, no card-grid, no bubbly radius, house Fraunces/Newsreader throughout, 2px radius matches existing `.signin__door`. |
| 5. Design system alignment | 7/10 | 9/10 | Reuses `.signin__door` anatomy exactly (real reuse, not reinvention) — but DESIGN.md never documented the second (destructive) variant. One-line Rule 6 amendment added. |
| 6. Responsive & accessibility | 6/10 | 9/10 | 44px tap target carried over unchanged; contrast was asserted, not verified — computed WCAG ratios now in the plan (4.76:1–5.21:1, all pass AA; the 5.14:1 destructive figure was corrected during eng review below). |
| 7. Unresolved decisions | — | 0 open | The one open item (destructive-tint opacity) decided in this pass, not deferred. |

**Overall: 6/10 → 9/10.** The 1 point held back is implementation-time, not
plan-time: `bin/ci` and the live-browser QA pass haven't run yet (T3/T4).

Mockups: not regenerated via the gstack designer — the owner already
reviewed and approved real mocks from a separate design round this
session (`https://claude.ai/code/artifact/828cce6a-ed95-4ec3-a204-8d006fdfe241`,
current-state + both `/you` states). Treated as the visual reference in
place of a new comparison board; regenerating a second set the owner
hadn't seen would have re-litigated an already-closed decision.

### Eng review (4-section)

**Step 0 scope challenge:** 1 file touched, 0 new classes/services — trivially
under the 8-file/2-class review trigger. No scope reduction needed; proceeded
straight to the 4 sections.

| Section | Findings | Notes |
|---|---|---|
| 1. Architecture | 0 | No new codepath, dependency, or security surface — pure selector restyle on 4 pre-existing classes. No ASCII diagram warranted (zero branches). |
| 2. Code quality | 0 (1 considered, kept as-is) | `rgba(163, 63, 40, …)` repeats `--warn`'s channels 3× rather than a single derived token. Considered `color-mix()` (safe for this app's iOS 17+ floor) but rejected — it would be the first use of that technique anywhere in `application.css`, and the file's own existing convention (`--hairline` is already a hand-written low-alpha duplicate of `--gold`'s channels) is exactly what this diff follows. Explicit-over-clever wins; 3 adjacent literals in one small block is a contained, low-drift duplication, not the DRY violation the preference guards against. |
| 3. Tests | 0 new codepaths → 0 new tests | Zero branches/conditionals added; the four classes' semantic behavior (which element, which href, which form action) is unchanged and already covered by `corners_test.rb`'s 20 tests, which is the actual regression surface. Visual/CSS coverage isn't Minitest's job in this codebase by existing convention (confirmed against ISSUE-002's precedent) — `/qa` (T3) is the real gate. IRON RULE doesn't trigger: the changed surface (rendering) has no prior Minitest coverage to regress. |
| 4. Performance | 0 | Static asset, zero queries, zero memory concern. |

**Outside voice:** Codex rate-limited (`ERROR: You've hit your usage limit`,
retry Sep 27 — consistent with this project's recent history). Fell back to
an independent Claude subagent with fresh context, told to verify the plan's
claims against the real code rather than trust its prose. 3 findings:

1. **(caught, fixed)** Contrast section computed `--warn` against plain
   `--bg` instead of the actual low-opacity composited tint — real number is
   **5.14:1**, not 5.56:1. Still clears AA with margin; the number was wrong,
   the ship decision wasn't. Fixed in the Accessibility section above.
2. **(caught, documented, not blocking)** `.push__enable` is the one chip
   that's an `<a>`, not a `<button>` — WebKit's long-standing quirk where
   `:active` needs an `onclick`/touch listener in the ancestor chain to fire
   on a plain link may mean this one control's new press-state doesn't
   actually trigger on tap. Unconfirmed whether it still reproduces on this
   app's iOS 17+ floor. Added as an explicit on-device check to T3 (Test
   plan section) with a named one-line fallback, rather than fixed
   speculatively for a bug not confirmed to exist.
3. **(self-resolving)** Flagged that the plan-as-written showed Eng Review
   as "0 runs, pending" while closing "NO UNRESOLVED DECISIONS" — a real
   observation about the document mid-review, not a gap: this section is
   that gate actually completing.

**Cross-model tension:** none. All three findings were additive/corrective,
not disagreements with the primary review.

**Failure modes:** none identified beyond the two documented above (both
non-silent — a wrong hex ships a visibly-wrong color, caught by `/qa`; a
missing `:active` ships a still-functional, still-fixed-at-rest control).

**Worktree parallelization:** not applicable — one file, sequential
implementation.

**Required outputs (NOT in scope / what already exists):** see the sections
above in this plan — both sections already cover the eng-review-relevant
material (existing `.signin__door` reuse, deliberate exclusions); not
duplicated here.

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | not run — not warranted (bug-class fix, not a scope/strategy question) |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | rate-limited; Claude subagent ran instead (see Outside voice above) |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clean | 0 issues across 4 sections; outside voice caught 1 numeric error (fixed) + 1 documented platform caveat (not blocking); 0 unresolved |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | clean | score: 6/10 → 9/10, 3 findings folded (active state, DESIGN.md amendment, contrast verification), 0 unresolved |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | not run — not warranted (CSS-only, no dev-experience surface) |

**VERDICT:** Design + Eng CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
