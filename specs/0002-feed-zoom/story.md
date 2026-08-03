# 0002 — Zoom in the archive
Date: 2026-08-03
Lane: Express (same-day, reversible)
Status: Built 2026-08-03 — code complete, awaiting deploy

## Who
**Maya** — Daily Ritual Learner, persona 1 (`specs/personas.md`) — on the days she taps
"Wander the full gallery" after her note and keeps scrolling.
Secondary: **Amara**, persona 3, who reads critically and wants to actually see the
brushwork she is being told about.

## Problem
The daily page and the archive now look identical — same paper, same masthead, the same
`.plate` component under the same wall label (`DESIGN.md`, shipped 2026-08-03). Tapping
the artwork on the daily page fills the screen with it. Tapping the artwork in the archive
does nothing at all. Same picture, same frame, same gesture, different result — so the
archive reads as broken rather than as a different screen. The archive is where somebody
scrolls past a hundred works; it is the screen where wanting a closer look is most likely,
and it is the one screen that refuses.

## Story
As Maya, I want to tap any artwork in the archive and see it full screen, so that the
gesture I learned on the daily page keeps working when I am browsing.

## Intake
- Evidence: Better bar 7, "Zoomable, high-quality images" (`CLAUDE.md`) is a quality bar
  applied to the product, not to one screen. The unification in `decisions/0003-one-skin.md`
  is what created the defect: before it, the two screens looked different enough that
  different behaviour was legible. Persona 4 (Tomás) compares us to Google Arts & Culture,
  where zoom is table stakes, but persona 4 is explicitly not baseline and is not the
  argument here — the argument is that we shipped an affordance that lies.
- Success signal (prediction): on the first dogfooding pass after this ships, tapping any
  artwork in the archive opens it full screen with the same asset the daily page shows,
  and no page in the archive gains more than one overlay in the DOM regardless of how far
  it is scrolled. Checkable the day it lands.
- In baseline? No — the archive is not a baseline surface. **The exception argued:**
  `decisions/0002-mvp-disposition.md` froze the feed ("zero new feature work") to protect
  the baseline's WIP limit. This is not new feature work: it is one existing component
  behaving the same way on both screens, no new model, no new route, no new controller,
  no new content. It is the same class of change as fixing a broken layout on the feed.
  If it needed a day of work it would wait for the Phase 3 gate; it does not.

## Acceptance
- Tapping any artwork in the archive opens it full screen — the same overlay, the same
  Close button, the same dark surround as the daily page.
- Escape or a tap anywhere closes it, and focus returns to the artwork that was tapped.
- The overlay shows the artwork that was tapped, not the first one on the page.
- Works for artworks loaded by infinite scroll, not just the first page.
- One overlay per page, no matter how many works are on screen — scrolling the archive
  does not accumulate hidden full-size images.
- An artwork whose image fails to load is not tappable and does not open an empty overlay;
  it shows the resting note, as on the daily page.
- The daily page's zoom behaviour is unchanged.

## Out of scope
- Pinch/pan magnification beyond the browser's own. The overlay shows the whole work at
  viewport size; deeper magnification is a separate question with its own evidence.
- Loading a higher-resolution asset for the overlay than the page already has.
  `artwork_src` is the one source for both screens; changing it is a different story.
- Favourites, deep links to a single work, keyboard paging between works.
- Any other change to the archive.
