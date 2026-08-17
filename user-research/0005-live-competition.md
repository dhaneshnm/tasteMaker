# Live Competition: the 43 apps that are actually running

**Project:** Tondo (Month 1, Fork B)
**Date:** 2026-08-16
**Purpose:** Cut `0004`'s 94-app catalog down to the apps that are genuinely operating — so
kill-review comparisons, ASO expectations, and "who am I up against" are measured against a
live shelf, not a graveyard. Companion to `0004` (the full catalog).
**Source:** derived entirely from `data/0004-app-landscape.json`. No new collection.
**Status:** Reference. Not a spec.

---

## 1. The filter

Three cuts applied to `0004`'s 94 in-category iOS apps, against the 2026-08-15 snapshot date:

| Cut | Rule | Removed | Left |
|---|---|---|---|
| — | 0004 catalog baseline | — | 94 |
| 1 | No App Store update in 12 months (before 2025-08-15) | 31 | 63 |
| 2 | Never updated after first release (`updated == released`) | 7 | 56 |
| 3 | Zero ratings ever | 13 | **43** |

**54% of the studied category is not a live competitor.** Total iOS ratings across the 43:
**58,850** — unchanged from the 56-app list, because every app cut in step 3 contributed zero.

Reproduce:

```bash
python3 -c "
import json
d = json.load(open('user-research/data/0004-app-landscape.json'))
CUT = '2025-08-15'
live = [a for a in sorted(d['apps'], key=lambda a: a['updated'], reverse=True)
        if a['updated'][:10] >= CUT
        and a['updated'][:10] != a['released'][:10]
        and (a.get('ratings_all') or 0) > 0]
print(len(live), sum(a['ratings_all'] for a in live))
"
```

---

## 2. The 43 — sorted by last update, newest first

Tier column uses `0004`'s tiers. **Bold** = Tondo's literal shelf (daily art feed).

| # | App | Developer | Tier | Updated | Released | Ratings | ★ |
|---|---|---|---|---|---|---|---|
| 1 | **Art History & Museum - Artify** | Hasret Özkan | 3 daily feed | 2026-08-13 | 2023-08-11 | 92 | 4.61 |
| 2 | ArtGuessr - Art Trivia & Quiz | Yauhen Siarko | 2 quiz | 2026-08-13 | 2026-05-22 | 24 | 4.96 |
| 3 | Connects: Arts+Culture | Bloomberg | 1 incumbent | 2026-08-12 | 2019-11-04 | 7,159 | 4.82 |
| 4 | **Afterglow Art: Eternal Gallery** | Mortara Studios | 3 daily feed | 2026-08-12 | 2026-07-20 | 4 | 5.0 |
| 5 | **Daily art history and modern** | Alberto Soto | 3 daily feed | 2026-08-11 | 2025-01-07 | 138 | 4.33 |
| 6 | Arrrt - Pocket Art Gallery | StarWeave | browser | 2026-08-11 | 2022-07-24 | 17 | 4.65 |
| 7 | Artera - Art for all | Artera | 4 reference | 2026-08-09 | 2024-02-14 | 12 | 5.0 |
| 8 | CANVS Street Art | CANVS | adjacent | 2026-08-07 | 2016-09-30 | 130 | 4.81 |
| 9 | **Daily Art History - Paintly** | Paolo Gambardella | 3 daily feed | 2026-08-07 | 2026-02-06 | 4 | 5.0 |
| 10 | FAEA: Florida Art Education | FAEA | adjacent | 2026-08-07 | 2019-09-05 | 1 | 3.0 |
| 11 | Smartify: Arts and Culture | Smartify CIC | 1 incumbent | 2026-08-06 | 2016-05-11 | 9,331 | 4.54 |
| 12 | **ArtHist: Art History & Museum** | Fatih Yörük | 3 daily feed | 2026-08-05 | 2025-08-12 | 111 | 4.86 |
| 13 | The Art of Ed Community | Art of Education Univ. | adjacent | 2026-08-05 | 2024-08-09 | 65 | 4.92 |
| 14 | Museum Lovers - Art & Gallery | Apps Bay | browser | 2026-08-04 | 2022-04-25 | 16 | 4.69 |
| 15 | **Curator - Learn Art History** ⚠️ | Zhuang Liu | 3 daily feed | 2026-08-03 | 2026-04-14 | 9 | 4.89 |
| 16 | Blast - Share Views, Chat | Oscar Lowe | adjacent | 2026-07-30 | 2026-05-31 | 47 | 4.45 |
| 17 | **LearnArt** | Maria Samoshenkova | 3 daily feed | 2026-07-19 | 2025-07-07 | 41 | 4.39 |
| 18 | **ArtDay: Daily Art Gallery** | ArtFlow | 3 daily feed | 2026-07-13 | 2025-07-03 | 58 | 4.84 |
| 19 | **EveryArt - Daily Art Gallery** | 鉴 郗 | 3 daily feed | 2026-07-04 | 2012-10-24 | 22 | 4.55 |
| 20 | Learn Art | Normand Martin | 2 quiz | 2026-06-29 | 2018-11-06 | 724 | 4.75 |
| 21 | Museumistic - Art at The Met | Erik Kelly | 4 reference | 2026-06-29 | 2024-06-20 | 11 | 5.0 |
| 22 | **Cultura: Learn Art History** | Aytek Aras | 3 daily feed | 2026-06-25 | 2025-12-15 | 1 | 4.0 |
| 23 | Leo Art | Joey Steigelman | 4 reference | 2026-06-22 | 2023-02-21 | 12 | 5.0 |
| 24 | Art Explora Academy | Art Explora | 4 course | 2026-06-21 | 2022-04-11 | 5 | 4.6 |
| 25 | NOUV - Gallery of Masterpieces | Awad Etman | browser | 2026-06-21 | 2026-03-31 | 2 | 5.0 |
| 26 | Art History & Painting - Artly | Pavel Kozemirov | 2 quiz | 2026-06-17 | 2020-12-30 | 2,363 | 4.68 |
| 27 | Kimbell Art Museum | Kimbell Art Foundation | venue | 2026-06-10 | 2013-11-08 | 20 | 3.8 |
| 28 | Asian Art Museum SF | Asian Art Museum Fdn. | venue | 2026-06-10 | 2014-10-22 | 10 | 2.7 |
| 29 | **Artlist - Masterpiece Theater** | Jinan Matrix | 3 daily feed | 2026-06-06 | 2019-01-22 | 644 | 4.67 |
| 30 | **Dastan: Daily Art & Poetry** | Majid Sadri | 3 daily feed | 2026-05-29 | 2026-04-14 | 3 | 5.0 |
| 31 | **DailyArt** ⚠️ | Zuzanna Stańska | 1 incumbent | 2026-05-28 | 2012-08-22 | 37,169 | 4.82 |
| 32 | Michael James Smith TV | PalettePro | adjacent | 2026-05-21 | 2020-02-12 | 129 | 4.92 |
| 33 | **For Art's Sake: Art History** | Paul Breslin | 3 daily feed | 2026-05-06 | 2025-04-28 | 17 | 4.53 |
| 34 | **Daily Dose of Art** | Jack Waslen | 3 daily feed | 2026-04-09 | 2024-12-08 | 4 | 5.0 |
| 35 | Famous Paintings Quiz | Horea Bucerzan | 2 quiz | 2026-04-03 | 2019-12-21 | 7 | 3.57 |
| 36 | Art Master | ArtCollection.io | 2 quiz | 2026-03-17 | 2020-03-18 | 157 | 4.68 |
| 37 | Wonder Wander: Explore Art | Shannon Steven | browser | 2026-02-13 | 2017-08-24 | 4 | 5.0 |
| 38 | **ArtBite: Daily Art Inspiration** | Hangzhou Guangheng | 3 daily feed | 2026-01-28 | 2025-07-28 | 9 | 5.0 |
| 39 | SC El Prado Masterpieces | Museo del Prado | 4 zoom | 2025-11-16 | 2014-03-20 | 7 | 3.29 |
| 40 | Art Quiz: paintings & artists | Iron Water Studio | 2 quiz | 2025-11-11 | 2019-03-14 | 69 | 4.61 |
| 41 | Who's the Painter? | Anton Malmygin | 2 quiz | 2025-10-22 | 2015-12-01 | 196 | 4.57 |
| 42 | Visual Arts | Ivan Flores | browser | 2025-09-24 | 2025-01-21 | 1 | 5.0 |
| 43 | **Connoisseur: Learn Art History** | Gray Leonard | 3 daily feed | 2025-09-18 | 2024-08-01 | 5 | 5.0 |

⚠️ = the two apps that matter most: DailyArt (category definition, Tondo's direct comparison)
and Curator (the positioning collision, per `0002` §3.5).

**Not in this list, but real competition:** Google Arts & Culture (133,528 ratings) and
Smart Art — Art History Escape (526) are documented in `0004` §2–3 but never landed in the
JSON sweep, so the filter can't see them. Treat the 43 as a floor, not a census.

---

## 3. Why these 43 matter

### 3.1 They set the real ASO barrier

`BET.md`'s Aug 31 threshold is 3 keywords ranked top 100. The competing set is not 94 apps
— it is these 43, and **the median among them is 17 ratings.** Only six clear 200:

| App | Ratings | What it is |
|---|---|---|
| DailyArt | 37,169 | The category |
| Smartify | 9,331 | Museum companion, effectively B2B |
| Bloomberg Connects | 7,159 | Philanthropy-funded venue guides |
| Artly | 2,363 | Biggest pure learner, 6 years |
| Learn Art | 724 | Solo dev, 8 years |
| Artlist | 644 | Non-Euro range, 7 years |

Everything else on the live shelf is under 200 ratings. Three of the six took 6–8 years to
get there. **Rating count, not app count, is the barrier** — and outside DailyArt it is low.

### 3.2 Maintenance is not traction — this is the load-bearing finding

Cut 3 removed 13 apps that are *actively maintained and have zero ratings*. Two are extreme:

- **artDatabase — The Art Guide**: released 2010, updated Jan 2026, **zero ratings in 15 years.**
- **Artie: Art History Watch&Learn**: released 2023, updated 2026-08-12 (3 days before snapshot),
  **zero ratings.** Ships video narration over zoomable paintings — a real product, invisible.

Nine of those 13 launched in 2026 and are still being worked on. They are not abandoned.
Nobody found them. This is the settled category fact — *distribution decides this category* —
appearing as measurable behavior rather than assertion. Shipping updates is not the input that
produces installs, and Tondo's own commit velocity is subject to the same rule (R7).

### 3.3 Free is the shelf, so free is not a differentiator — calm is

**42 of the 43 are free to download.** The single paid app is SC El Prado at $3.99, with 7
ratings in 12 years. Tondo's "free at launch" baseline buys no position by itself.

What is unoccupied is *free with nothing between push and art*. Per `0004` §7, every incumbent
with traction either runs ads (DailyArt, Artly) or paywalls the archive, and DailyArt's
monetization friction is its single largest review-surface liability (`0002` N2: 82 of 1,465
reviews touch payment, anger clustered at 1–2★). The Better bucket's calm bar is the
differentiator; free alone is table stakes.

### 3.4 The wave is younger than it looks, and thinner

15 of the 43 released since Jan 2025; 7 since Jan 2026. Of that 2025–26 cohort, exactly one
clears 100 ratings (ArtHist, 111). Supply is accelerating far faster than expressed demand
(`0002` §3.3) — but so far none of it converts. The concept is cheap; nobody has been rewarded
for it yet.

### 3.5 Every dead app died by neglect, not by competition

Zero 2026-released apps failed cut 1. All 31 apps removed for staleness predate 2026, and five
of them walked away carrying real traction — Louvre HD (394), Art Challenge (366), Art
Masterpieces Quiz (218), Art Academy (182), Famous Paintings Widget (157). The category does
not kill apps. Builders quit. That is the same failure mode `BET.md`'s kill discipline exists
to make deliberate rather than accidental.

### 3.6 Coaching audit — 5 of 43 claim to teach looking, none ships it

All 43 App Store descriptions read and graded. Question: does the app claim to teach the
*user's own looking* — appreciation as a skill — or does it deliver facts about artworks?

**Grade A — explicit "learn how to look" claim (5 apps, 51 ratings combined):**

| App | Ratings | The claim | What the description says ships |
|---|---|---|---|
| Curator | 9 | "see paintings with the eye of someone who knows what to look for… noticing the gesture, the light, the composition" | Visual quizzes, mini-games, guided challenges — **recognition** |
| ArtBite | 9 | "a story that sharpens your eye" — daily story about "color, light, and composition"; "learn to spot each artist's style" | Daily editorial + collect-apples-by-movement mechanic |
| Connoisseur | 5 | "train you to identify the artist and movement by only looking at the painting"; author's framing: "sight-read paintings in museums" | Slide-ID exam drilling |
| ArtGuessr | 24 | "Train your eye… identify the artist from a single detail" | Guess-the-artist quiz |
| Wonder Wander | 4 | "SEE, SAY, and DO activities to deepen your experience"; built by an art educator | **The only prompt-based looking routine found** — but on public murals and sculpture, not paintings |

**Grade B — appreciation by explanation, no looking claim (27 apps):** deliver the "why"
(context, symbolism, technique) attached to the work. Builds knowledge, does not train the eye.
Editorial feed (21): DailyArt, Artlist, Artify, Daily art history and modern, For Art's Sake,
LearnArt, EveryArt, Arrrt, Cultura, Visual Arts, Museumistic, Paintly, Leo Art, Museum Lovers,
CANVS, Blast, Smartify, SC El Prado, Bloomberg Connects, Asian Art Museum SF, Art Explora
Academy. Quiz with post-answer explanation (6): Artly, Learn Art, ArtHist, Art Master, Art
Quiz, Famous Paintings Quiz.

**Grade C — no teaching layer (11):** Afterglow, ArtDay, Artera, NOUV, Dastan, Daily Dose of
Art, Who's the Painter?, Kimbell, FAEA, The Art of Ed Community, Michael James Smith TV
(teaches *making*, not appreciating).

**`0004` §7 holds on the live shelf.** No app among the 43 prompts you to look at a specific
region of a specific painting and tells you what to notice there. All five Grade-A apps claim
the outcome and ship a recognition drill — "train your eye" is ASO copy for guess-the-artist.

Three consequences:

1. **The claim is contested; the traction is not.** Five apps, 51 ratings between them. The
   four painting-focused ones are Tondo's direct positioning rivals and none clears 25 ratings.
2. **The closest real mechanic is misfiled.** Wonder Wander's SEE/SAY/DO is the only actual
   observation-prompt structure in the category, and `0004`'s tiering never flagged it because
   it sits in public art. Worth reading before writing any coached-looking spec.
3. **SC El Prado stays the near-miss `0004` named.** Gigapixel super-zoom plus audioguide on 14
   Prado works — keyed to details, but linear and narrated. You listen; you never look-then-check.

**This audit reads marketing copy, not software.** Curator could ship keyed prompts inside its
"guided challenges" and the description would not say so. Installing Curator, ArtBite and
Connoisseur — three free apps, one afternoon — is the cheapest check available before any
coached-looking spec, and it retires the largest single limitation in both `0004` and this file.

---

## 4. Use at kill review (2026-08-31)

`0002` §6.1 named the wave as a free instrument. This list makes it operable.

**Re-run the filter against a fresh iTunes sweep and check:**

1. **Does any 2025–26 cohort app cross 100 iOS ratings?** Today only ArtHist has (111). If none
   of Curator / Paintly / Connoisseur / ArtBite / ArtDay does, the latent-demand thesis is
   weakened from a second independent direction — at zero cost to Tondo.
2. **Does the live count grow or shrink?** 43 today. Growth means the shelf is still crowding;
   shrinkage means the 2026 wave is entering its abandonment phase on schedule.
3. **Does Curator ship coached looking, or stay a quiz?** It uses Tondo's framing near-verbatim
   and is maintained (updated 2026-08-03). If it ships actual keyed observation prompts, the
   `0004` §7 finding "nobody ships coached looking" is dead and the New slot needs rethinking.

**Wrong-if for this document:** if a 2026-cohort app crosses 500 iOS ratings by kill review
*without* hand-written editorial or non-Euro curation, then the moat thesis in `0002` §6.5
(differentiation must be craft, not concept) is falsified — execution quality would not be
what the category rewards, and distribution alone would be.

---

## 5. Limitations

- **Derived, not collected.** Every figure inherits `0004`'s snapshot of 2026-08-15, US
  storefront, iTunes Search API. Nothing re-verified live.
- **The filter is mechanical.** `updated == released` catches ship-once apps but also flags
  genuinely new ones — ArtBrain was 8 days old at snapshot and got cut as ship-once. Three of
  the seven cut in step 2 were under a month old.
- **Zero ratings ≠ zero users.** US-storefront lifetime rating counts only. An app with Android
  traction and no iOS ratings (e.g. What The Art: 35,078 Play installs, 1 iOS rating) is
  invisible to cut 3 — though that one failed cut 1 anyway.
- **The 43 is a floor.** Google Arts & Culture and Smart Art are live competitors absent from
  the source JSON. Venue-specific museum guides were excluded from `0004` on purpose, yet
  Kimbell and Asian Art Museum SF survived the filter — category membership is imperfect.
- **No app was installed or used.** Same caveat as `0004`: descriptions are marketing copy.
  "Guided challenges" and "train your eye" are claims, not verified behavior.
