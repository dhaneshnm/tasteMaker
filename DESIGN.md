# Tastemaker — design system

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

## Components

`.masthead` — one bar for every screen. Brand top-left, what-this-screen-is
under it in italic, and one fact on the right: the pick's date on the daily
page, the work count in the archive.

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
3. **Never truncate a title.** Long titles step the type down instead.
4. **Prose is `--ink`. Metadata is dim.** Dates, medium, credit, counts step
   back; the words a person wrote do not.
5. **Nothing hovers over a painting.** The masthead is not sticky, there are no
   floating buttons, no overlays except the full-screen view the user asked for.
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

That is the only one.

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
