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
| `--gold` | `#7d5f18` | Links, artist names, the ornament. 5.3:1 |
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

### Contrast

Linen lights on the gold field measure **5.3:1** — the same ratio the token table
records for gold on linen, since it is the same pair inverted. WCAG 1.4.11 asks
3:1 of a graphical object. Measured, not assumed.

---

## Components

`.masthead` — one bar for every screen. Brand top-left, what-this-screen-is
under it in italic, one fact on the right (the pick's date on the daily page,
the work count in the archive), and the compass under all three.

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

`.coda` — the closing beat. Ornament, a line in display italic, sometimes a
note and a link. Ends the daily ritual, ends the archive, carries the empty
state.

`.post` — one item in the archive. Adds the spacing and the rule between works.

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

`.keep` — the last row of the wall label, where a reader keeps a work. A
`.caps-link`-scale button in `--gold`, and once there is something to count, the
way into the collection beside it. It sits **inside `.label`**, `2.2rem` below
the credit — deliberately more air than the credit's own `1.3rem`, because equal
spacing would group it with the credit block instead of reading as an action.

**Left-grouped, never spread.** `justify-content: flex-start` with a `1.6rem`
gap. Spread across the measure the two items sit 466px apart at 1280, which stops
reading as a pair and starts reading as `.walk`, which is a different kind of
thing one screen further down.

**No glyph in the kept state.** `Keep this` becomes `Kept · Remove` — words and
the middle dot `.label__credit` already uses. `✦` was tried and rejected: it is
the product's only ornament (rule 6), and using it as a state mark put two of
them within one screen meaning different things. The state is carried by the
words, the colour, and `aria-pressed`.

`.walk` — previous / next day at the foot of a past day. Two `.caps-link`s, and
nothing else; the way back to today sits under them.

`.sentinel`, `.zoom`, `.adm` — infinite-scroll spinner, full-screen view,
curator's desk.

---

## Rules

1. **One skin.** No page-scoped palette overrides. If a screen needs a colour,
   it comes from the token table.
2. **Never crop an artwork.** `contain`, letterboxed against the paper. Cropping
   is an editorial decision and we are not making it on the viewer's behalf.
   Making it *smaller* is allowed and sometimes required: `.plate__img` is capped
   at `min(55vh, 55dvh, calc(100dvh - 19rem))`, so at large text sizes the
   picture yields height to keep the first written line above the fold. At the
   default root size the third term is within 4px of 55vh and nothing moves.
   A smaller picture, never a cropped one.
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
6. **One rule, one ornament.** The hairline under the masthead and the `✦`
   divider are the only decoration. No cards, no shadows, no rounded corners
   beyond the 2px on form controls.
7. **Motion is a fade.** The archive's scroll-in reveal and the zoom fade, both
   off under `prefers-reduced-motion`. Nothing slides, bounces, or springs.
8. **Text is never clamped on the daily page.** The archive clamps museum
   catalogue copy to four lines with a `More` toggle, because there the point is
   the pictures. The hand-written note is the whole point and is shown whole.
9. **Anything you can tap is at least 44px tall.** `.caps-link` sets size and
   tracking, not height, so every control built on it adds `min-height: 44px`
   itself — `.walk__step`, `.zoom__close`, `.keep__toggle`, `.days__remove`.
   ISSUE-002 (commit 866bbc2) shipped 15px targets once by assuming otherwise.

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

Those are the only two.

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
