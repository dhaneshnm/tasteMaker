# 0034 — A frame for the doors

Date: 2026-09-02
Lane: **Full (≤ 3-day core).** Owner's explicit call regardless of scope. CSS +
small view changes, one file, no model/migration — small for a Full story, but
`/plan-design-review` is required before implementation (owner's call, this
session: run it formally even though the visual direction is already approved
on the mock).
Status: Draft.
Numbering: 0034 taken now, no clash — `specs/0033-whose-words`' own note says
the dark `0030-the-standing-bar` branch claims a number *when it resumes*, not
in advance.
Branch: `0034-a-frame-for-the-doors`.

## Who

- **The owner, as dogfooder.** Live production `/you` page, signed in with
  Apple, 2026-09-02: "This does not look right. These are just text and
  unusable to the user."
- Every reader who reaches `/you` in either the `:account` or `:device` state
  — the only screen in the product where this pattern appears.

## Problem

**Four controls on `/you` render as flat gold tracked-caps text with zero
box, border, or fill — indistinguishable from inert copy.** `.signin__out`,
`.account__delete`, `.push__enable`, `.push__disable`
(`app/assets/stylesheets/application.css:1513-1535`) are real, working
`<button>`/`<a>` elements — 44px tap target, `cursor: pointer`, wired to real
actions (Sign out, Delete account, Delete device, the notification toggle) —
but nothing about their appearance says so.

This is not a stale-CSS or missing-stylesheet bug (ruled out: the page's
color, tracking, and italic display type all render correctly). It is the
deliberate "quiet controls" treatment chosen in `specs/0015-the-two-keys/plan.md`
and explicitly re-affirmed in the 2026-08-17 design-review QA pass
(ISSUE-002, `application.css:1573-1589`) — which fixed spacing but kept flat
text as house style. This story reverses that call for cause: a real dogfood
report, not a hypothetical.

The app already proves the fix inside itself. `.signin__door` ("Continue with
Apple/Google," same file, same screen's `:device`/`:signed_out` states) has
carried a bordered chip — hairline border, `--bg-lift` fill, 2px radius — since
story 0015, sits two inches from the flat controls, and has never drawn this
complaint.

## Story

Extend `.signin__door`'s existing chip anatomy to the four flat controls, in
two variants:

- **Safe** (`Sign out`, notification toggle): hairline border, `--bg-lift`
  fill, `--gold` text — same chip shape as `.signin__door`, gold kept for
  continuity with the rest of the product's action color.
- **Destructive** (`Delete account`, `Delete device`): `--warn`-tinted border
  and text on a faint warm fill — visually distinct from safe actions,
  consistent with standard platform convention for irreversible controls.

`Privacy` / `Support` (`.legal`) stay plain caps-link text, unchanged —
navigation, not action; the three-way distinction (safe chip / destructive
chip / plain link) is the point.

No copy changes. Every string stays byte-identical to what ships today.

Approved mocks (both states, plus the current-state reference for
comparison): https://claude.ai/code/artifact/828cce6a-ed95-4ec3-a204-8d006fdfe241

## Evidence

- Owner's live-production screenshot and direct complaint, 2026-09-02 — the
  trigger.
- Repeat signal, not a first read: ISSUE-002 (design review, 2026-08-17)
  already flagged this exact affordance question once and chose to keep flat
  text; the same visual language produced the same complaint again, this time
  from a live account rather than a review pass.
- Within-product A/B, unintentional but real: `.signin__door` (bordered) has
  shipped since story 0015 with zero complaints; the flat controls it sits
  next to drew one on first live dogfood.

## Success signal — falsifiable, time-bound

Pre-live only — `BET.md` still reads zero installs, so there is no funnel to
instrument yet; this is a dogfood-stage bar, not an analytics one.

- **Next 5 live opens of `/you`** (owner, real device, both `:account` and
  `:device` states hit at least once): no hesitation or double-check before
  tapping Sign out, Delete account, Delete device, or the notification
  toggle — the specific complaint that opened this story does not recur.
  Fails if it does; the chip treatment is wrong, not just unfinished.
- **Post-live (deferred, named not hidden):** once the App Store approval
  lands and installs exist, a support contact or review specifically about
  not finding/trusting a control on `/you` would falsify this a second time.
  No window set — there is no install base yet to bound one against.

## Non-goals

- No third button weight (no filled/high-contrast/CTA style) — exactly two
  variants, safe and destructive. Owner's explicit "minimal affordance" call.
- No change to `.signin__door`, compass, wings facet doors, `.legal` links,
  or the keep/share rail glyphs — all confirmed correct and out of scope.
- No new differentiator claim — this is a defect fix in the same class as
  ISSUE-002, not new Better-bucket ground.
- No exploration of whether destructive actions need a confirmation-dialog
  redesign — `turbo_confirm` stays exactly as it is; only the button's
  resting appearance changes.
