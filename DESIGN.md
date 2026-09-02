# Tondo — design system

One room, one light. Every screen in the product uses the components below.
When something new gets built, it reuses these; a new visual idiom needs a line
in this file saying why.

Source of truth for the values: `app/assets/stylesheets/application.css`.
This file says *what* the choices are and *why*.

---

## The idea

**"The morning room."** Warm linen paper, ink type, an old gold that is dark
enough to read. The daily artwork is meant to arrive like a page in a book you
read with your tea — not like a feed.

Rejected: the earlier "museum at night" dark skin on the archive. Two skins
meant the archive and the daily pick read as two different apps, and the jump
between them broke the calm. Adopted the linen page everywhere on Aug 3, 2026.

---

## Tokens

Colour, all contrast ratios measured on the linen paper:

| Token | Value | Use |
|---|---|---|
| `--bg` | `#f4efe6` | Paper. Every page. |
| `--bg-lift` | `#ece5d8` | Behind an image while it loads, form fields, flash panels. |
| `--ink` | `#2a241c` | Prose and titles. 13.4:1 |
| `--ink-dim` | `#635a4c` | Metadata: medium, dates, table body. 6.0:1 |
| `--ink-faint` | `#6f6456` | Credit lines, captions, hints. 5.1:1 |
| `--gold` | `#7d5f18` | Links, the ornament, and an artist name **only when it links** (story 0018) — the unlinkable fallback, and every artist name on `/`, step back to `--ink-dim` instead. 5.3:1 |
| `--gold-deep` | `#5f4711` | Hover only. |
| `--warn` | `#a33f28` | Form errors, off-target hints. Nothing else. |
| `--hairline` | `rgba(125, 95, 24, 0.3)` | Rules under the masthead and table headers. |
| `--frame-edge` | `rgba(42, 36, 28, 0.18)` | The 1px edge around an artwork. |
| `--mount-bg` | `#100e0b` | The full-screen surround, and nothing else. The accepted exception below. |

Everything above AA at the size it is used. No colour outside this table.

Type:

- Display — **Fraunces**, `--serif-display`. Titles, brand, the closing line.
- Body — **Newsreader**, `--serif-body`. Everything else, including small caps.
- `--measure: 42.5rem` — the reading column. Nothing gets wider.

Two families, no third. Weight range stays 380–560; nothing is bold.

---

## Brand

The product is **Tondo** — Italian, clipped from *rotondo*, "round": a painting
made in a circle. Decided 2026-08-10, `decisions/0007-the-name-is-tondo.md`,
executed by story 0011.

It was called Tastemaker until then. That name survives on purpose in
`SHIPLOG.md`, in `decisions/0001`–`0006`, and in the specs for stories that had
already shipped — those files record what was built and when, and rewriting them
would falsify the record rather than tidy it.

### The mark

A rose window, which is the other great round picture of the period and the one
that is pure ornament. Not the wedges-and-hub version: eight wedges meeting at a
centre is a pie chart, and no colour fixes that. The real structure instead —
**lights** (lancets that stop short of the centre and cap in an arch), an
**oculus**, and a **tracery band**. Nothing reaches the middle, so there is no
hub for lines to converge on, and every edge is a curve answering the circle.
A ruled line argues with a circle; that is why the earlier horizon-and-band
marks were dropped.

**The gilt field is the tile.** Gold fills the icon edge to edge and the window
is cut out of it in linen. The first version had it the other way round — a gold
rose on a linen tile — and rendering it killed that: on a light or photographic
wallpaper the linen tile has no edge, so the square disappears and the rose
floats unattached. Gold holds its own boundary against anything behind it.
Recorded rather than quietly reversed, because the paragraph this file used to
carry claimed the opposite (`specs/0011-rename-to-tondo/plan.md`, design review
2026-08-10).

Authored at `viewBox="0 0 1024 1024"`, centre `512 512` — the App Store icon's
own coordinate space, so the proofed drawing and the shipped PNG are the same
numbers. Colour is `--bg` and `--gold` only.

**Rose, full** — twelve lights, with the tracery band:

| Element | Geometry |
|---|---|
| Field | full bleed, `--gold` |
| Tracery band | `circle r=396`, stroke `--bg` at 0.55, width 12 |
| Lights | 12 × `M-32 -145 L-76 -284 A76 76 0 0 1 76 -284 L32 -145 Z`, fill `--bg`, rotated 30° apart about the centre |
| Oculus | `circle r=96`, fill `--bg` |

**Rose, small** — eight heavier lights, **no tracery band**. Same window, fewer
mullions, which is what a real one does in a smaller opening:

| Element | Geometry |
|---|---|
| Lights | 8 × `M-44 -170 L-96 -270 A96 96 0 0 1 96 -270 L44 -170 Z`, fill `--bg`, rotated 45° apart |
| Oculus | `circle r=122`, fill `--bg` |

Outermost ink reaches r=402, which is inside the 409.6 safe radius a maskable
PWA icon is cropped to. That is why the band sits at 396 and not further out.

**Which drawing at which size — measured, then written down.** The first version
of this file guessed that twelve lights silt up below 120px. Rendering both
drawings at every shipping size and looking at them magnified says otherwise:

| Size | Drawing | Why |
|---|---|---|
| 1024, 180, 120 | full | Room for everything; the band is a band |
| 87, 80 | full | Petals still separate, band still reads. The guess said these were too small; they are not |
| 60, 58 | small | At 60 the tracery band closes against the petal tips and the gaps between twelve lights begin filling in |
| 40 | small | Eight heavy lights are the floor. Twelve is mush here |

The table lives in `script/brand-render` as `FULL_SIZES` / `SMALL_SIZES` and is
enforced by `test/integration/brand_assets_test.rb`. Change it by re-rendering
and looking, not by reasoning.

**29 and 16 are not shipped.** Neither drawing survives them — the design review
predicted a third plain-roundel drawing would be needed and it still would be.
iOS derives Settings and Spotlight renditions from the sizes above, and the
favicon is `icon.svg`, which is vector and does not downsample at all.

**Every raster is downsampled from 1024, never drawn at its target size.**
Painting the SVG directly at 40 or 16 makes each pixel a hard gold-or-linen
decision and turns thin lights into blocks; averaging down from 1024 keeps the
edges. It is also what Apple and browsers do to the icon anyway, so what ships
matches what was proofed.

**Two appearances are drawn, one is inherited.** iOS renders every home-screen
icon light, dark and tinted. Tinted gets its own drawing — grayscale, mid-grey
field and a white window, because desaturating gold yields one flat value with
nothing left in it. Dark reuses the light art: gold is already dark enough to
sit correctly among dark neighbours. **If `--gold` ever lightens, that
assumption dies and dark needs its own drawing.**

The tinted image ships **at 1024 only**, on the universal single-size slot.
`appearances` is not a valid key on a legacy per-size entry: adding tinted
variants next to the `idiom: iphone` slots builds green and emits *"the app icon
set AppIcon has 9 unassigned children"*, which means Xcode read them, could not
place them, and dropped them. The icon would have shipped with no tinted
appearance and nothing would have failed. So the per-size entries carry the two
drawings, one universal entry carries the appearance, and iOS derives the rest.

A one-colour version exists for print and anywhere gold cannot go: the field
becomes `--ink`, lights and oculus stay `--bg`, and the tracery band drops.

### The wordmark

Fraunces, three settings, gold on linen. No fourth.

| Setting | Spec | Where |
|---|---|---|
| Masthead | Fraunces 500, `opsz` 144, tracking −0.01em, mixed case | `.masthead__brand`, every screen |
| Caps | Fraunces 480, `opsz` 144, uppercase, tracking 0.22em | launch screen (0.24em), screenshot captions |
| Lockup | mark + Fraunces 500, gap ≈ 0.3em, optically centred on the mark | App Store screenshots, the site |

**The launch screen is the caps wordmark alone**, on linen, shipped as a static
image so it needs no font. The mark is deliberately *not* on it. Once the field
went gilt the mark became a filled gold square, and a filled gold square is the
loudest thing that would ever appear on the calmest surface in the product. The
launch screen's job is to be linen before the linen page arrives.

Consequence, accepted: the mark appears on the home screen and in the App Store
and **nowhere inside the app**. That is correct. Inside the app the artwork is
the subject and a logo would be a second one.

**Amended 2026-08-17, story 0017.** What that bans is the *tile* — the gilt
field, whole or in part, at lockup size. The objection above is specific and it
is about ink: a filled gold square is the loudest thing that would ever appear
on the calmest surface in the product. It is not an objection to the window's
geometry.

So one element of the drawing may be borrowed back, under the conditions the
functional-glyph rule already sets: **the oculus**, as an outline in `--gold` on
linen at the 23px / 1.4px / 44px contract, as the corner mark. That is the
inverse of the banned thing — linen field, gold line — and it carries the same
ink weight as the keep bookmark that has been inside the app since story 0006.

The ban stands for everything else: no tile, no lockup, no rose, no gilt field,
at any size, on any screen inside the app. If `--gold` ever lightens, or if the
corner is ever asked to be filled rather than drawn, this amendment lapses and
the original sentence governs again.

### Contrast

Linen lights on the gold field measure **5.3:1** — the same ratio the token table
records for gold on linen, since it is the same pair inverted. WCAG 1.4.11 asks
3:1 of a graphical object. Measured, not assumed.

---

## Components

`.masthead` — one bar for every screen. Brand top-left, what-this-screen-is
under it in italic, one fact on the right (the pick's date on the daily page,
the work count in the archive), the corner mark in the far corner, and the
compass under all four.

`.masthead__you` — the corner (story 0017). The reader's own room, reached from
every screen that wears this bar. `--gold`, 23px oculus in a 44px target, the
same drawing contract as the two glyphs in `.rail`. It spans the brand and label
rows and takes its height from them, which is why it costs nothing: that band
already measures over a touch target at the accessibility cap. It is **not** on
the compass row and cannot be — at 375px that row is 312.23 of the 329.0px the
page leaves, and a fifth item needs 58px against 16.77px of spare. On `/you`
itself it loses its link and steps back to `--ink-dim`, the same way the compass
marks the screen you are standing on.

**Nothing in this bar may vary by reader.** It renders inside `/`, which is
`Cache-Control: public` behind Thruster. A corner that showed a signed-in state
would put per-visitor markup into a shared cache. It also renders on
`/privacy` and `/support`, whose controller inherits `ActionController::Base` —
so no `current_user`, no `current_device`, no `native_shell?`. View logic only.

`.compass` — where else you can go. Four destinations, **always all four**, in
one order everywhere: `TODAY · DAYS · KEPT · GALLERY`. The label says which one
you are on; the compass marks it by taking its link away — same `.caps-link`
type, same tracking, same 44px box, `--ink-dim` instead of `--gold`, and
`aria-current="page"`. Rendering only "the other three" was tried and rejected:
it moves every label one slot depending on the screen, which is the opposite of
learning the set once. An archived day and the 404 mark nothing, because neither
is one of the four surfaces.

**The copy is one word each because the row costs 44px.** Rule 9 applies to
every item, and `.caps-link` sets size and tracking but never height. Measured at
375px with Dynamic Type at its cap, four one-word labels fit on one row and four
two-word labels wrap to two — and the second row comes straight out of the space
above the artwork. The gap is clamped rather than set in `rem` for the same
reason: a `rem` gap grows with the text exactly when there is least room for it.

`.compass--rail` — the same component, sticky, on `/feed` only. See the
accepted exception below.

`.page` — the reading column. `--empty` variant centres an empty state.

`.plate` — an artwork. `.plate__img` is `object-fit: contain` capped at 55vh,
`.plate__zoom` is the tap target where zoom exists, `.plate__resting` is what
shows when the image fails.

`.label` — the wall label under a picture: `__title` (`--long` steps the size
down), `__artist` + `__artist-name` + `__artist-dates`, `__meta`, then the
prose (`__note` for the hand-written note, `__text` for museum copy),
then `__credit`.

`.conv` — the conversation under the picture (story 0033, `decisions/0023`,
replacing the sit gate). A comment thread in the product's own materials:
the museum or curator voice is a **pinned comment** (`.cmt__pin`, a native
`<details>` — opens with no JS), the reader's own line is a comment beside
it. Both wear a **medallion** — 32px circle, `--bg-lift` fill, hairline
edge, a Fraunces monogram in `--gold-deep` — **drawn, not filled gold**: a
gilt disc on the calmest page in the product would be the exact tile rule 6
already refuses (see that rule's amendment). The pin's summary states its
own bar (`.cmt__fold`, rule 9) and carries a **chevron**, two static
orientations swapped instantly on `[open]` — deliberately the idiom this
file used to say the product never showed; it shows one now, and rule 7's
"nothing rotates" holds because the flip is a state change, not a motion.
The reader's own name is a `<span>` at weight 500, **never bold** — a bare
`<b>` would be the first control in the product to break the 380–560 weight
range — with the answer keeping the display italic already established for
the reader's voice (F14, unquoted, unboxed). Relative time reads **"today"**
or the date, never a lying "this morning," server-rendered inside the
private frame so no client clock is ever consulted.

Front door only carries the toggle: a rail glyph (`--gold`, filled when
open — the same fill-for-state grammar Keep already taught, never a colour
shift) shows or hides the whole `.conv` block, open by default, remembered
closed for the day only in `localStorage`. The pin itself starts folded
there — write-first, now carried by the fold rather than by a reveal event
— and the reader's own slot is a composer (the day's prompt as the field's
visible label) until answered, after which it is a comment, tap to edit
while the day is still theirs. The archive and preview render the identical
markup permanently open, pin expanded by default, no JS mounted at all —
browsing is not practice.

`.coda` — the closing beat. Ornament, a line in display italic, sometimes a
note and a link. Ends the daily ritual, ends the archive, carries the empty
state.

`.post` — one item in the gallery (`/feed`) or on an artist page. Adds the
spacing and the rule between works. **Carries its own `.rail`** since story
0020 — Keep alone, no Zoom, no count; see `.rail` below for the full account
of how that differs from `/`'s.

`.days` — the contents list of past days. One row per day: the date in small caps,
the title, the artist, and an uncropped thumbnail on the right (112px desktop,
72px phone; fixed height, free width, so a hanging scroll stays a scroll). Rows
are separated by a hairline and whitespace — **never a card**: no fill, no border
box, no radius, no shadow, on any state including hover. Month names are `<h2>`.

**The one place the label's colours invert.** In `.days` the title takes `--gold`
and the artist steps back to `--ink-dim` — the opposite of `.label`. In a list the
title is the *target* and gold is the link colour; on the day page the title is
the *subject* and the artist carries the accent. Without the inversion the only
gold in the row belongs to the one part that does not navigate.

`.rail` — the row of actions **directly under the plate**, above the wall label.
Line icons in `--gold` at a 23px box, `1.4px` stroke, each in its own 44px target
(rule 9). **On `/` and `/days/:date`: Zoom, Share (shell-only), the
conversation bubble, then Keep.** Decided 2026-08-14,
`decisions/0010-actions-become-a-rail.md`; the bubble joined 2026-09-01,
`decisions/0023`.

**On `/feed` and `/artists/:slug`: Keep alone** (story 0020). Two differences
from the rail above, both because the surface is different, not because the
component is:

- **No Zoom.** The plate is already the zoom trigger on these two screens
  (`shared/_plate.html.erb`), and both already mount `shared/_zoom` —
  unlike `/`, where the plate competes with a wall label for attention and
  zoom was added to the rail for exactly that reason (`decisions/0010`). A
  second zoom control here would be a duplicate tab stop for one action.
- **No count.** See "The count keeps its word" below.

Same tokens, same targets, same glyph — one component, fewer children on the
walled surfaces.

**Zoom is first, and Keep is last, as a stable convention now rather than a
load-bearing one.** Keep used to grow on fetch when its count arrived,
shoving whatever sat to its right — the reason Zoom led and Keep trailed.
The count left the frame entirely with the "N kept" text
(`decisions/0023`), so Keep is a fixed 44px box in both states and nothing
grows any more. The order stays: it is still where a reader's thumb finds
it, and re-ordering a control nobody asked to move is its own kind of
churn.

**The bubble sits between Share and Keep, filled when open.** Same fill-for-
state grammar as Keep's own kept mark — no colour shift, no second mark —
so the rail keeps one state language across both its toggles. `--gold` in
BOTH states: a dim glyph in an otherwise-gold row would read as disabled,
which it never is.

**The frame ships default content — on `/` and `/days/:date`, and only there.**
The un-kept outline glyph is identical for every visitor, so it is not personal
data and belongs in the cached page; only the filled state comes from the
private fragment. Without it the rail paints an empty 44px box where
the habit mechanic should be for as long as the fetch takes, which is the same
bug moved from the bottom of the page to the top.

**On `/feed` and `/artists/:slug` there is no fetch to cover** (story 0020).
Both are walled and private — no shared cache for a live `button_to` to
poison — so `paintings/_painting.html.erb` renders the real control inline,
with no `src`, from the first paint. The mark is correct immediately; the
placeholder-then-private-fragment split exists only where a public page forces
it. Do not "fix" the walled surfaces back into fetching frames — that would
reintroduce the loading state this design deletes, for no benefit, since the
constraint the split answers (`/` is `Cache-Control: public` behind Thruster)
does not hold there.

**No labels, and that is why the targets state both axes.** Rule 9 says
`min-height` and nothing about width, because every control it names is a
`.caps-link` and words make those wide for free. These have no words: left as
written the target would be 23px across. `.rail__act` states `min-width` as well,
and both read `--tap`.

**`.rail__slot` reserves nothing, deliberately.** It briefly carried its own
`--tap` box against the frame landing and shoving Zoom sideways. Neither half of
that is a risk any more: the frame ships default content, so the box is drawn by
a real `.rail__act` before the fetch resolves, and Zoom sits *before* the frame,
so a frame that grows has nothing to its right to move. Reserving it a second
time would be scaffolding for a default that is tested to exist.

**The count is gone from every surface** (story 0033, `decisions/0023`,
reversing the narrowing below). `decisions/0010` bought the label-less rail
with two mitigations: the count as a teacher on `/`, and the accessible
name on every glyph everywhere. The count's teaching job is confronted, not
quietly dropped — the accessible name is now the ONLY thing on any rail
telling a first-time reader what a glyph does, and it is unchanged,
full-strength, on every screen that carries one. Accepted with eyes open:
Keep's fill still self-demonstrates on first tap, and the bubble's one
Instagram misreading ("other people's comments") is bounded by what it
opens — one tap shows two voices and no crowd. If dogfooding says the
bubble reads as social chrome anyway, the tripwire is the medallion
retreat named in `.conv` above, not a label brought back.

**`/feed` and `/artists/:slug` stayed mark-only all along** (story 0020,
`/plan-design-review` D1, 2026-08-19) — the surfaces that used to differ
from `/` only by lacking a count now render identically to it in that
respect. What still marks them apart is structural, not decorative: no
Zoom (the plate is already the zoom trigger there) and no bubble (no `.conv`
machinery mounts outside `daily/_day.html.erb` at all).

**It sits next to the artwork because that is what fixes the fold.** Actions used
to be the last row of the wall label, which put the product's only habit mechanic
40–60pt below the fold on a fallback day and several hundred below on a
hand-written one — rule 8 shows that note whole, so the page a curator writes is
the *taller* one. Position next to the plate does not depend on note length.

**Left-grouped, never spread.** `justify-content: flex-start`. Spread across the
measure the items sit 466px apart at 1280, which stops reading as a pair and
starts reading as `.walk`, a different kind of thing one screen further down.
Instagram spreads; it can, at 402pt, and this cannot, at 680.

**A bookmark, not a heart.** Heart means *like* — a signal aimed at another
person. This product has no social graph and the action is called Keep, which is
save-for-later. **The kept state is the filled glyph** — no colour shift, no
second mark — and the accessible name carries what `Kept · Remove` used to say in
words. `aria-pressed` is unchanged; it never depended on the label.

**The rail costs one touch target on rule 2's third cap term, on every screen
that carries one** — the reserve goes `19rem` → `19rem + var(--tap)`, and the
split is the point. The `19rem` is the label's text budget and scales with
Dynamic Type; the rail's height does not, because a finger does not get bigger
when a reader raises their text size. The plan said `22rem` and
`dynamic_type_test.rb` rejected it: charging a fixed cost in `rem` billed the
picture 60px it never spent. Free at 402×874, where 55vh still wins.
**−44px** of artwork at 375×667, on works tall enough to be height-capped.
That trade is the one rule 2 allows: a smaller picture, never a cropped one.

Decided for `/` and `/days/:date` on 2026-08-14; extended to `/feed` and
`/artists/:slug` on 2026-08-19 (story 0020, `/plan-design-review`) — not a new
trade, the same one, on two more screens that now carry the rail. On `/feed`
this repeats **once per post**, ~110 times down the product's only unbounded
scroll; accepted as the price of the control existing where the reader found
the work, not discovered later.

`.walk` — previous / next day at the foot of a past day. Two `.caps-link`s, and
nothing else; the way back to today sits under them.

`.signin__doors` / `.signin__door` — the two house buttons (story 0015; rehomed
by 0017). `--bg-lift` field, `--hairline` border, the 2px form-control radius,
44px minimum height, Newsreader labels ("Continue with Google / Apple") led by
the provider's official mark at 18px — Google's multicolour G, Apple's mark in
`--ink`. Recognition lives in the logos, not the providers' button chrome. In
the shell, and for any device identity, they do not render at all: the app
never shows login UI, and Google answers an embedded web view with a 403.

They used to sit in a lazy `signin` turbo-frame at the foot of the landing
page, whose id was also the anchor every wall bounce landed on. Story 0017
deleted that fragment — with `.signin`, `.signin__note` and `.signin--in` — and
moved the doors to `/you`. The landing page now carries no per-visitor markup
at all.

`.account` is the sibling at the foot of the collection: the signed-in line
and, since 0017, a `Your corner` signpost rather than the delete button itself.
The destructive controls live in the corner, one home each.

`.sentinel`, `.zoom`, `.adm` — infinite-scroll spinner, full-screen view,
curator's desk.

---

## Rules

1. **One skin.** No page-scoped palette overrides. If a screen needs a colour,
   it comes from the token table.
2. **Never crop an artwork.** `contain`, letterboxed against the paper. Cropping
   is an editorial decision and we are not making it on the viewer's behalf.
   Making it *smaller* is allowed and sometimes required: `.plate__img` is capped
   at `min(55vh, 55dvh, calc(100dvh - 19rem - var(--rail-reserve) - var(--pin-reserve)))`,
   so at large text sizes the picture yields height to keep the first written
   line above the fold. At the default root size the third term is within 4px
   of 55vh and nothing moves. `--rail-reserve` is `0` everywhere except the
   screens carrying an action rail, where it is one touch target.
   `--pin-reserve` is `0` everywhere except the front door's threaded state
   (`.page--thread`, story 0033), where the pin's own fold row is a second
   fixed row before the note — 15px, not the full touch target it measures,
   because a full `--tap` here pushed the accessibility-cap shrink past the
   25% ceiling `dynamic_type_test.rb` polices; 15 is the largest reserve that
   still clears it, solved from that test's own inequality. One rule, three
   varying terms, so the `19rem` is not written down twice. A smaller
   picture, never a cropped one.
3. **Never truncate a title.** Long titles step the type down instead.
4. **Prose is `--ink`. Metadata is dim.** Dates, medium, credit, counts step
   back; the words a person wrote do not.
5. **Nothing hovers over an artwork.** No floating buttons, no overlays except
   the full-screen view the reader asked for, and the masthead is not sticky on
   the screens whose job is one artwork — `/` and `/days/:date`.
   **`/feed` is the one exception, and it is spent on navigation only, never on
   branding.** The gallery is the product's only unbounded screen: 110 works of
   infinite scroll, a masthead that scrolls away, and a coda that renders on the
   last page, so two flicks in there was no way out on screen at all. The
   `.compass--rail` stays; the wordmark, the label and the count do not. Nothing
   changes shape as you scroll — there is no cross-browser way for CSS to know
   an element has become stuck, and buying that knowledge with scroll-watching
   JavaScript to hide a wordmark is not a trade this product makes.
   **The gallery index door (story 0027) joins the rail, not the masthead** —
   it is the one filter control that survives scrolling, by design: the three
   in-flow facet rows it replaced were never sticky and cost 44px of fold
   budget per line. Navigation, same as the four destinations beside it.
6. **One rule, one ornament.** The hairline under the masthead and the `✦`
   divider are the only decoration. No cards, no shadows, no rounded corners
   beyond the 2px on form controls.
   **Functional glyphs are not ornament.** Line icons that are controls —
   `--gold`, 23px box, 1.4px stroke, 44px target — are allowed wherever the
   control is: `.rail` under the plate carries Keep and Zoom, `.masthead__you`
   carries the corner, and `.compass--rail` carries the gallery index door
   (story 0027) — a floor plan, fill-only state change, the same idiom Keep
   already taught. They are not decoration, which is what this rule was
   protecting when it read *"no glyph in the kept state."* Amended 2026-08-14,
   `decisions/0010-actions-become-a-rail.md`; widened 2026-08-17 by story 0017.
   The exception is for controls only; a decorative second mark is still refused.

   The 2026-08-14 wording added *"and they never share a screen with the ✦"*.
   That clause was **already false when it was written** — `daily/_day.html.erb`
   renders `.rail` and the `✦` on the same page, every day, on `/` and
   `/days/:date`. Removed rather than enforced: a rule nothing has ever obeyed
   is a rule that teaches the next reader to distrust this file.

   **Identity medallions are the one shape exception, and they are drawn, not
   filled (story 0033, `decisions/0023`).** `.cmt__avatar` is a 32px circle,
   never a gold one — `--bg-lift` fill, a hairline edge, the same frame every
   artwork already wears. A filled gold disc there would be the exact gilt
   tile the wordmark section's own amendment bans at lockup size: "no tile...
   at any size, on any screen inside the app." The rule stands; medallions are
   inside it, not an exception to it.

   **Two chip weights, not one.** `.signin__door`'s anatomy (hairline
   border, `--bg-lift` fill, 2px radius) now has a destructive sibling —
   `--warn`-tinted border and fill, same shape — for actions that cannot be
   undone. Story 0034, `decisions/0024-the-doors-get-a-frame.md`.
7. **Motion is a fade.** The archive's scroll-in reveal and the zoom fade, both
   off under `prefers-reduced-motion`. Nothing slides, bounces, or springs.
8. **Text is never clamped on the daily page.** The archive clamps museum
   catalogue copy to four lines with a `More` toggle, because there the point is
   the pictures. The hand-written note is the whole point and is shown whole —
   **whole once the pinned comment is expanded** (amended by story 0032,
   re-amended by story 0033): the front door folds the note's *entrance*
   behind one tap on the pin, and only there. The words are never cut, only
   their moment moves; `/days/:date` still shows the pin expanded by default.
9. **Anything you can tap is at least `--tap` (44px) in every direction it has.**
   `.caps-link` sets size and tracking, not height, so every control built on it
   states the bar itself — `.walk__step`, `.zoom__close`, `.rail__act`.
   ISSUE-002 (commit 866bbc2) shipped 15px
   targets once by assuming otherwise.
   **Width counts too, and only bare glyphs have to say so.** A caps-link gets
   width for free from its words; `.rail__act` has none, so it states
   `min-width` as well. The number is the `--tap` token rather than a literal,
   because story 0014 put it in four places at once and a bar that half-lands is
   the same failure ISSUE-002 was.
   **An inline link inside running text states the bar with `padding-block`,
   not a bigger box.** `display: inline-block` plus a negative margin was
   drafted first for `.label__artist-name` (story 0018) and rejected: it
   turns the name into an atomic box that cannot wrap where `.label__artist`
   already does on plenty of works, raising a fold-budget question that
   padding on a plain inline element does not.
   **The padding is sized against the font's own content-area metrics, not
   the paragraph's line-height — measure, do not read it off the cascade.**
   `getBoundingClientRect()` on an inline non-replaced element tracks its
   content area (font-size-ish, here ~16px), not `.label__artist`'s
   1.02rem × 1.4 line-height (22.85px); line-height set on the element itself
   changes nothing about that box. `application.css`'s comment on
   `.label__artist-name` targets 46px rather than 44 for exactly this reason
   — the formula's base is an approximation of a font metric no CSS unit
   exposes, so the target clears the bar with margin instead of landing on
   it by luck.

---

## Accepted exceptions

**The full-screen view is dark** (`--mount-bg`, `#100e0b`). At full screen the
picture is the room, and a linen surround bounces light into it. Mount board,
not wall.

**The gallery's compass is sticky** (`.compass--rail`, `/feed` only). Written
into rule 5 above rather than left implicit, because it is the one place
something stays on screen over scrolling artwork. Navigation only: it is 58px of
links, versus the 104px a sticky masthead measured — 16% of an iPhone SE screen
parked over the pictures for the whole scroll. `z-index: 1`, so `.zoom` (20)
covers it and `body::after`'s paper tooth (3) passes over it like everything
else.

**Google's G is the only non-token colour in the product** (story 0015,
design review D4). It appears inside `.signin__door`'s mark and nowhere else:
the mark is the recognisable half of the sign-in door, and desaturating it to
gold would keep the room at the cost of the door. Confined to those buttons;
any second appearance of these colours is a violation of rule 1, not a
precedent.

Those are the only three.

It used to be a hardcoded hex, which rule 1 does not allow and which story 0008
could not mirror into the iOS asset catalogue. It is a token now, and the native
shell reads the same value from `Assets.xcassets/MountBg.colorset`.

The exception is also why `viewport-fit=cover` is set. Without it WebKit keeps
the layout viewport out of the notch and home-indicator strips, so the surround
stops short of both and the wall shows through in linen — the exact thing this
paragraph exists to prevent.

---

## Where it came from

The quality bars this system is built to satisfy live in `CLAUDE.md` (Better
bucket) and the evidence in `specs/personas.md`:

- Art and text visible together (bar 2) → the 55vh cap on `.plate__img`, tested
  at 375×667 in `test/system/daily_test.rb`.
- Calm, no ads, no upsell (bar 4) → rule 5 and rule 6.
- Zoomable, high-quality images (bar 7) → `.zoom`, and rule 2.
