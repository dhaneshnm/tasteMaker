# App Landscape Catalog: "Learn / Look At Art" Category

**Project:** Tondo (Month 1, Fork B)
**Date:** 2026-08-15
**Purpose:** Complete inventory of the category Tondo ships into. Every app that claims to teach
art history or deliver curated art daily, with what it actually does, its traction, and its
price. Companion to `0002` (demand validation) and `0003` (content reference library).
**Method:** iTunes Search API sweep — 24 queries, 366 apps collected, 94 in-category after
filtering out painting tools, museum-venue guides, and games. Google Play data (install bands
+ exact install integers) and pricing verified live by web research on 2026-08-15. Raw data:
`data/0004-app-landscape.json`.
**Status:** Reference. Not a spec.

---

## 1. Headline numbers

| Fact | Figure |
|---|---|
| In-category iOS apps found | **94** |
| Released since Jan 2025 | **33** (23 of them in 2026 alone, through mid-August) |
| Of those 33, apps with ≥100 iOS ratings | **2** |
| Of those 33, apps with ≥25 iOS ratings | **5** |
| Median iOS rating count, 2025–26 cohort | **1** |
| Median iOS rating count, whole category | **9** |
| Apps with literally zero ratings | **20** |
| Largest pure *learning* app (iOS ratings) | **Artly, 2,363** |
| Largest app in category (iOS ratings) | **DailyArt, 37,169** — a feed, not a course |
| Largest adjacent daily-learning app | **Imprint, 52,203** / **Nibble, 46,153** — same mechanic, other subjects |

**Read:** the category is crowded and shallow. One incumbent feed, one mid-size quiz app, and
a long tail of near-identical launches that never reach double-digit ratings. Two general
daily-learning apps outweigh the entire art-learning cohort combined — the mechanic works,
the subject is the constraint.

---

## 2. Tier 1 — the incumbents

### DailyArt · Moiseum (Zuzanna Stańska)
**What it is:** one curated artwork per day with a short human-written story. Archive of 4,000+
masterpieces, 1,200 artist biographies, 600 museum collections, curated Collections, City
Guides, search, favorites, widgets, 23–24 languages. The category definition, and Tondo's
direct comparison.
**Traction:** iOS 37,169 ratings, 4.82★ · Play **6,123,133 installs** (band 5M+), 4.7, 219K
ratings · 9M downloads self-reported · ~800K monthly users (2025 press).
**Money:** free with ads. Premium $4.99/mo, $29.99/yr; Patron $119.99; tips $1.99–$99.99.
Paywall buys ad removal + full archive access. Legacy one-time PRO buyers grandfathered.
Web shop sells separate courses ($8–34) — and gives away one titled *How To Look At Art* free.
**Released** 2012-08-22 · **updated** 2026-05-28.
**Weak points (from 1,465 reviews mined in 0002):** ads and paywall creep dominate complaints;
82 reviews touch payment, anger clustered at 1–2★ — "Locking art and the history of that art
behind a paywall is foul"; "$120 a year?!"; broken purchase-restore for legacy buyers.

### Google Arts & Culture · Google
**What it is:** 2,000+ institutions, 80 countries. Gigapixel Art Camera zoom, Art Selfie, Art
Transfer, Pocket Gallery AR, Art Recogniser, a 100+ item "Play" hub (Puzzle Party, Odd One Out,
Cultural Crosswords, What Came First?, Art Aura), plus AI layers — One Minute Guides, Talking
Tours, Learn Everything. Homepage has Story of the day / Artist of the day.
**Traction:** iOS 133,528 ratings, 4.68★ · Play **15,933,301 installs** (band 10M+), 4.2.
**Money:** free, no ads, no IAP. Unbeatable on price by definition.
**Note:** despite 100+ playables, there is **no quiz tab and no coached-looking feature**.
Knowledge-testing is scattered across novelty games. Its daily surfaces are shallow.

### Smartify · Smartify CiC
**What it is:** museum companion — scan an artwork to identify it, audio tours for 700+
institutions, trip planning, ticket booking. Effectively B2B: revenue from institution partner
plans, not consumers. Raised £1.5M (Jan 2025) to expand institutional partnerships.
**Traction:** iOS 9,331 ratings, 4.54★ · Play **1,223,229 installs**, 4.6.
**Money:** free, **no ads, no subscription.** Optional per-museum audio tours $0.99–$3.99
(Louvre $1.99, Met $1.99, Ashmolean $3.99), framed as supporting the venue.
**Relevance:** proves the in-gallery job monetizes only through institutions.

### Bloomberg Connects · Bloomberg Philanthropies
**What it is:** free digital guides for 700+ museums/cultural sites; philanthropy-funded.
**Traction:** iOS 7,159 ratings, 4.8★, 56 languages · Play **3,266,440 installs**, 4.2.
**Money:** free, no IAP, forever. Another floor-setter.

---

## 3. Tier 2 — quiz / recognition drills (the "Duolingo for art" shelf)

Every app here drills *recognition* — name the artist, name the movement. None coaches looking.

| App | Developer | iOS ratings | ★ | Released | Updated | Notes |
|---|---|---|---|---|---|---|
| **Artly — Art History & Painting** | Pavel Kozemirov | **2,363** | 4.68 | 2020-12-30 | 2026-06-17 | Category's biggest pure learner. Movement-by-movement quiz ladder (Renaissance → Contemporary), difficulty rises as artworks get obscurer. Play: **2,289,354 installs**, 4.5, 24.3K ratings, contains ads, IAP $2.49–$36.99. Reddit verdict: "breaks down each art period and quizzes you… doesn't go that in depth"; one asker called it "a dry copy-paste of Wikipedia" |
| **Learn Art** | Normand Martin | 724 | 4.75 | 2018-11-06 | 2026-06-29 | Solo dev, 10 years running. 510 paintings, 85 painters, 30 movements. Four modes: pick-the-painter, pick-the-painting, letter quiz, movement quiz. Explicitly "no banners, no forced ads." iOS only |
| **Smart Art — Art History Escape** | Ask Connoisseur LLC | 526 | 4.8 | 2020-07-08 | 2026-06-08 | 1,000+ stories + quizzes over an 80K-painting library. iOS only ($4.99/mo, $29.99/yr) |
| **Art Challenge: Quiz Game** | Zipo Apps | 366 | 4.46 | 2017-11-15 | 2024-11-16 | Trivia-app-factory build, 17 languages, hearts/hints/certificate. Going stale |
| **Art Masterpieces Quiz** | Roberto Alcazar | 218 | 4.41 | 2013-07-27 | 2020-06-04 | 450 works, guess-the-artist. Abandoned 6 years |
| **Who's the Painter?** | Anton Malmygin | 196 | 4.57 | 2015-12-01 | 2025-10-22 | 300 works, 25 levels, relaxing music. Family framing |
| **Art Academy: Fun Art Quiz Game** | Xiang Dong | 182 | 4.87 | 2021-11-12 | 2025-04-04 | 100 canonical works, 900 questions, 90 levels, tap-to-zoom on details, no ads, fully offline. Highest-rated of the drills |
| **Art Master** | ArtCollection.io | 157 | 4.68 | 2020-03-18 | 2026-03-17 | Category-picker (Contemporary / Old Masters / Urban), points + badges + leaderboard |
| **Art Quiz: paintings & artists** | Iron Water Studio | 69 | 4.61 | 2019-03-14 | 2025-11-11 | Battles vs other players, puzzle-unlocks-story mechanic, "Painting of the Day" section |
| **Art: Quiz Game & Trivia** | Daniel Baczkowski | 69 | 4.0 | 2018-08-04 | 2020-09-25 | Dead |
| **Ginkgo Art History** | Ginkgo Academy | 24 | 4.42 | 2022-07-17 | 2025-04-09 | Spaced-repetition flashcards + video-in-flashcard. Closest thing to an actual SRS curriculum |
| **ArtGuessr — Art Trivia & Quiz** | Yauhen Siarko | 24 | 4.96 | **2026-05-22** | 2026-08-13 | "Train your eye… identify the artist from a single detail." New wave |
| **Explore Art History Game** | 4Genera | 9 | 4.8 | 2023-09-27 | 2023-12-27 | Dead |
| **Famous Paintings Quiz** | Horea Bucerzan | 7 | 3.6 | 2019-12-21 | 2026-04-03 | 34 languages, 7 ratings |
| **Oil on Canvas: Art Quizzes** | Artyom Alekseev | 1 | 2.0 | 2021-12-06 | 2025-07-16 | — |
| **Artlingo: Learn Art. Daily.** | Daniel Kadic | **0** | — | **2026-03-05** | 2026-03-22 | "Trains visual recognition… learn by seeing, identifying, responding." Name says the whole strategy. Zero traction, no update in 5 months |

---

## 4. Tier 3 — daily-feed apps (Tondo's literal shelf)

| App | Developer | iOS ratings | ★ | Released | Updated | Notes |
|---|---|---|---|---|---|---|
| **Artlist — Masterpiece Theater** | Jinan Matrix (CN) | 644 | 4.67 | 2019-01-22 | 2026-06-06 | HD downloads, 5 new paintings/week, explicit ukiyo-e + Chinese classical coverage — rare non-Euro range |
| **Daily art history and modern** | Alberto Soto | 138 | 4.33 | 2025-01-07 | 2026-08-11 | "In Daily Art, there are no ads." Bite-sized lessons. 339MB |
| **ArtHist: Art History & Museum** | Fatih Yörük | 111 | 4.86 | 2025-08-12 | 2026-08-05 | "Designed by an art historian." 1,000+ questions, 5,000+ artworks, 50+ museums with per-museum quizzes, Artwork of the Day, progress analytics. Play: 6,116 installs. IAP $4.99–$49.99. The most complete of the new wave |
| **Art History & Museum — Artify** | Hasret Özkan | 92 | 4.61 | 2023-08-11 | 2026-08-13 | Storytelling + "stunning high-resolution zoom" + Art Dictionary. Pitches casual and student modes |
| **ArtDay: Daily Art Gallery** | ArtFlow (KR/JP) | 58 | 4.84 | 2025-07-03 | 2026-07-13 | 5 works each morning, 300K+ public-domain works, search by color/movement. Aimed partly at designers needing copyright-free reference |
| **LearnArt** | Maria Samoshenkova | 41 | 4.39 | 2025-07-07 | 2026-07-19 | 1M artworks, 600 museums, 4,500 biographies, 23 languages — a near-clone of DailyArt's feature list. iOS only. $79.99/yr, $129.99–199 lifetime |
| **EveryArt — Daily Art Gallery** | 鉴 郗 | 22 | 4.55 | 2012-10-24 | 2026-07-04 | 8+ years running, explicitly includes Chinese/Korean/ukiyo-e. 22 ratings after 14 years — the long-tail lesson in one row |
| **For Art's Sake** | Paul Breslin | 17 | 4.53 | 2025-04-28 | 2026-05-06 | Daily insight + quizzes + deep-dives "by real art historians." Play version effectively unlaunched: **69 installs**, no update since May 2025 |
| **ArtBite: Daily Art Inspiration** | Hangzhou Guangheng | 9 | 5.0 | 2025-07-28 | 2026-01-28 | Taste-profile quiz → personalized daily pick + story "that sharpens your eye"; "Apple challenge" collection mechanic. iOS only |
| **Curator — Learn Art History** | Zhuang Liu | 9 | 4.89 | **2026-04-14** | 2026-08-03 | ⚠️ **The positioning collision.** "Helps you see paintings with the eye of someone who knows what to look for… not a list of dates to memorize. It is a way of looking: noticing the gesture, the light, the composition… TRAIN YOUR EYE" via visual quizzes, mini-games, guided challenges + a personal gallery. r/ArtHistory launch scored 106/40 comments ("test invite please" ×N; also "screams AI coded stuff"). iOS only |
| **Connoisseur: Learn Art History** | Gray Leonard | 5 | 5.0 | 2024-08-01 | 2025-09-18 | Art-history "slide ID" exam drilling — teaches sight-reading a painting's artist/movement. Academic framing. iOS only |
| **Daily Art History — Paintly** | Paolo Gambardella | 4 | 5.0 | **2026-02-06** | 2026-08-07 | Daily painting in 2 min + personalization algorithm + **streaks**. Play: **701 installs, 2.8★** |
| **Daily Dose of Art** | Jack Waslen | 4 | 5.0 | 2024-12-08 | 2026-04-09 | Premium themed collections (Monet, Myths & Monsters, The Art of the Body) |
| **Afterglow Art: Eternal Gallery** | Mortara Studios | 4 | 5.0 | **2026-07-20** | 2026-08-12 | Four weeks old |
| **Dastan: Daily Art & Poetry** | Majid Sadri | 3 | 5.0 | **2026-04-14** | 2026-05-29 | Art + poetry pairing — one of the few genuinely differentiated angles |
| **Cultura: Learn Art History** | Aytek Aras | 1 | 4.0 | 2025-12-15 | 2026-06-25 | Art + literature canon in one archive |
| **FindArt — Daily art history** | A. Furkan Süren | 1 | 5.0 | 2024-10-29 | 2025-03-13 | — |
| **ArtTok: Daily Art & Museums** | Melih Atalay | **0** | — | 2026-03-03 | 2026-03-19 | — |
| **Kimp — Daily Art History** | Alexandre Prothee | **0** | — | 2026-02-23 | 2026-06-01 | — |
| **Arsillo — Art & Paintings** | Mark Soltyk | **0** | — | 2025-09-24 | 2026-07-30 | — |

Also present with zero ratings, same shelf: *Art History Master* (2026-06), *Artify — Learn
Art History* (2026-01), *Stories. Learn Art History* (2026-07), *Galero: Art History Game*
(2026-07), *Hidden Arts: Art History* (2026-02), *Voyart* (2026-06), *ArtGallery — Daily
Masterpiece* (2026-05), *Artie: Art History Watch&Learn* (2023, still 0).

---

## 5. Tier 4 — zoom, tours, reference, courses

| App | What it is | iOS ratings | Status |
|---|---|---|---|
| **SC El Prado Masterpieces** (Second Canvas / Madpixel) | Gigapixel deep-zoom of 14 Prado masterpieces with guided detail tours + TV-out. Mechanically the closest thing to keyed observation prompts that ships — but linear, narrated, passive | **7** (3.29★), $3.99 | Alive, museum-funded, negligible consumer traction |
| **SC Saint Louis Art Museum** | Same engine, another venue | 3 | Alive |
| **Artie: Art History Watch&Learn** | Video narration over zoomable paintings, "for art lovers who don't know where to start and find technical explanations boring" | **0** | Alive, updated Aug 2026, still zero |
| **Art Explora Academy** | Free nonprofit learning paths + videos/podcasts, **certification validated by Sorbonne University** | 5 (iOS); Play **48,756 installs** | Alive. Institutional content, free, still tiny on iOS |
| **Leo Art** | Met collection browser + biographies + favorites | 12 | Alive |
| **Museumistic — Art at The Met** | Met browser | 11 | Alive |
| **Artera / Art Authority Museum** | Reference collections | 12 / 5 | Alive |
| **What The Art — History Courses** | Art-history *courses* + zoomable gallery + interactive tests. The 2022 attempt at exactly the structured-course idea | 1 (iOS, last update 2023-04); Play 35,078 installs, 3.8, last update **Nov 2023** | **Dead.** Got 35K Android installs, then stopped |
| **Obelisk Art History** (web) | Free reference: 4,585 artworks, 547 artists, 341 original essays, quizzes. Solo-built by Reed Enger | no app | **Alive but stalled** — newest sitemap entry 2024-01-07; Patreon count hidden since 2020 |

---

## 6. Adjacent benchmarks — same mechanic, other subjects

| App | iOS ratings | Play installs | Money | Why it matters |
|---|---|---|---|---|
| **Imprint: Visual Micro Learning** | **52,203** (4.8★) | 1,248,590 | IAP $15.99–$99.99 | Interactive tap-through visual lessons across many subjects. Reviewers note only ~one art-history topic exists |
| **Nibble: Daily Learning & Quiz** | **46,153** (4.3★) | 2,823,504 | IAP $6.99–$89.99 | Daily learning + quiz. The r/ArtHistory asker who wanted "a mobile app… quiz me" specifically mentioned Nibble ("lots of people say it's a scam") |

Each of these two beats the **entire** art-learning cohort. The daily-quiz mechanic monetizes
fine — it just doesn't monetize *on art*, which is the same conclusion 0002 reached from the
demand side.

---

## 7. What nobody ships

Verified across all 94 apps (descriptions read; Play + web cross-checks in 0002 §3.5):

1. **Keyed observation coaching.** No app prompts you to look at a specific region of a specific
   painting and tells you what to notice there. Closest: Second Canvas (linear audio, 7 ratings),
   Artie (video narration, 0 ratings), Project Zero's *Zoom In* routine (classroom, not an app).
2. **Hand-written editorial at daily cadence.** DailyArt is the only one with a visible human
   editorial voice at scale, and its reviewers name it: "Every piece of art is given context in a
   personal way — no AI here!" The 2026 wave is being publicly accused of the opposite.
3. **Curation beyond the Euro-canon.** Only Artlist (Chinese/ukiyo-e) and EveryArt make it a
   stated feature. It is the most common complaint against everyone else.
4. **A free-and-calm daily habit.** Every incumbent either runs ads (DailyArt, Artly, Paintly,
   What The Art) or paywalls the archive. Free-with-no-ads is currently held only by tiny apps
   (Daily art history and modern, Learn Art, Art Academy) and by Google/Bloomberg, who don't
   compete on daily editorial.

---

## 8. Consequences for Tondo

1. **ASO threshold is harder than when BET.md was written.** 23 new in-category apps in 2026
   alone, most bidding on "art history," "learn art history," "daily art." Against the Aug 31
   target of 3 keywords in the top 100: the shelf is deeper, but the competition is *weak* —
   median 1 rating, most with one language, several unmaintained. Rating count, not app count,
   is the real barrier, and it is low everywhere except DailyArt.
2. **Traction ceiling is the sobering number.** Best pure learning app in the category's history:
   2,363 ratings over 6 years. BET.md's 50-install floor sits far below that, so the bet is
   safe — but nothing here suggests a large upside from this shelf.
3. **The differentiator is contested on copy, empty on execution.** Curator (9 ratings), ArtBite
   ("sharpens your eye"), ArtGuessr ("train your eye"), Artlingo ("visual recognition") all use
   the language; all ship recognition drills. Tondo's opening is executing what they describe.
4. **Free-with-no-ads is a live, differentiating position** — the incumbent's most-complained-about
   surface, and unoccupied by anyone with traction.
5. **Free instrument for the Phase 3 gate** (per 0002 §6.1): re-pull this catalog at kill review.
   If Curator / Paintly / Connoisseur / ArtHist are still under ~100 ratings, the latent-demand
   thesis for Priya (persona 7) is weakened by public evidence, at zero cost to us.

---

## 9. Limitations

- iOS figures from the iTunes Search API, US storefront, 2026-08-15. Rating counts are
  lifetime and all-locale; star averages are Apple's own.
- Category membership decided by keyword filtering plus manual review; venue-specific museum
  guides (Met, Getty, Rijksmuseum, ~40 of them) and painting-creation tools were excluded on
  purpose. A handful of borderline apps may be missing.
- Apple's legacy review RSS now returns entries only for DailyArt among these apps, so review
  *text* evidence in this document is DailyArt's (n=1,465, mined in 0002) plus Reddit/Play
  commentary. Other apps contribute counts and stars only.
- Play install integers come from the live listing payload via web research; bands are Play's
  public display. Only the 17 apps in that check have Android data — the rest are unverified
  on Android (many are iOS-only, verified individually for the named ones).
- App descriptions are marketing copy. "Guided challenges" and "train your eye" were read as
  claims, not verified by installing and using the apps. Installing the top 5 is the obvious
  next step before any coached-looking spec.
- Snapshot only. This shelf changed materially in the last 8 months and will change again.
