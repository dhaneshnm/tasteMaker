# 0019 — The coverage fill
Date: 2026-08-19
Lane: Full (core). Honest size: **1–2 days.**
Status: Draft — promoted from `IDEAS.md` Considering (top entry) when story 0018 Release 1
shipped and deployed, 2026-08-19.

Split out of story 0018 by `/plan-eng-review`, 2026-08-18 (E5). The seed spec survives
verbatim under "Release 2" in `specs/0018-the-names-you-know/plan.md`. This story is that
seed, promoted with intake fields and **corrected by measurement** — see `plan.md` §
"What the dry run changed".

## Who

- **Maya** — persona 1, CORE (`specs/personas.md:10`). The driver. The gallery-test
  participants searched *recognizable* names — greatest-hits level, which is Maya's
  knowledge level. She is the one who looks for a name she knows and finds nothing.
- **Tomás** — persona 4, Reference Browser. Release 1 gave him the artist page; this
  story decides whether the page he lands on is worth landing on. Not the driver — his
  ask (`/artists/:slug` exists at all) already shipped.
- **Amara** — persona 3, Educated Depth-seeker — the guard rail, not the requester.
  "Repeated tired old Van Goghs which are already super famous." A recognizable-name fill
  skews Euro-canon by construction. Her bar: **the fill must not regress the range bars
  0013 fought for**, and it is enforced by `verify!`, not by intention.
- Not in this story: Jordan (favorites untouched), Priya/Zoe (Phase 3 gate).

## Problem

**The pool is missing artists a visitor would obviously look for, and nothing in the
build could see it.** Story 0018's P2, now measured rather than reported.

Measured 2026-08-19 over the committed manifest and the four museum mirrors, first by a
48-name hand-probe and then — after the probe turned out to be wrong three ways — by
`bin/rails pool:coverage`, the task this story builds:

- **32 names are absent from the shipped pool while sitting unused in the mirrors** —
  Katsushika Hokusai (16 qualifying works available), Frans Hals (16), Sandro Botticelli
  (8), Utagawa Hiroshige (8), Canaletto (8), Jacopo Tintoretto (5), Johannes Vermeer (5),
  Albrecht Dürer (4), Gustav Klimt (2), Hieronymus Bosch (2) and 22 more. Every one is
  public domain, every one clears the 0013 bars, and the curator took none of them. These are not acquisition gaps. They are **selection** gaps: the
  quota table optimises range, era and readable text, and is blind to whether anyone has
  heard of the artist.
- The counts above come from `bin/rails pool:coverage`, the task this story builds — not
  from the hand-probe that started it. **The probe said ten, and three of its ten were
  wrong**: Titian (2 works), Caravaggio (1) and El Greco (3) are in the shipped pool
  already. Their real problem is the fragmentation below, which this story deliberately
  does not fix, so pointing the fill at them would have fixed nothing.
- **A second, larger gap sits underneath the first: the same artist is spelled several
  ways and becomes several artists.** Museums write "Goya", "Francisco de Goya",
  "Francisco José de Goya y Lucientes" and "Goya (Francisco de Goya y Lucientes)" for
  one man. Matching a name to works by exact slug — which is what the app does — finds
  **0 Goya works**; matching through the artist's Wikidata aliases and stripping the
  museum's own parentheticals finds **29**, scattered over four separate artist pages.
  Same shape for Turner (0 → 7), Kandinsky (0 → 8), Rembrandt (17 → 42), El Greco
  (3 → 12), Titian (4 → 9). **Three names this story first recorded as absent from the
  collections were present the whole time and were missed by the matcher, not by the
  museums** — that error is kept here rather than quietly edited out, because it is the
  finding: any coverage number computed by exact-slug matching is too low, and the first
  version of this story's own headline count was one of them.
- **Some names are unavailable at any effort**, and they are two different unavailables.
  Copyright-walled 20th-century names (Kahlo, Picasso, Dalí, Warhol, Basquiat, Kusama,
  Rivera, Chagall, Pollock, Hopper — CC0 sources are public-domain only) are one. A name
  genuinely held by none of the four collections is the other: **Michelangelo Buonarroti**
  has zero rows across all four mirrors and died in 1564. Reporting him as "walled" would
  blame copyright for a collection gap, so the report keeps the buckets apart.
  Georgia O'Keeffe is on neither list — she ships **three CC0 works** today, which is why
  the split is decided per name and by hand rather than by a rule about death years.
- **The evidence this rests on:** gallery hallway tests, 2026-08-15/16, 7 participants
  (`user-research/0006`, source memo 2026-08-14) — P2, participants looked for artists
  they already knew and did not find them. The hand-probe above is the first time that
  complaint was turned into a count.
- **What is already decided and does not reopen:** 0013's quota bars; 0005's museum-note
  fallback (so the fill costs zero mandatory editorial); 0013's banned ingest sources;
  and the settled category fact that **aggregation is the strategic trap** — the 10–20K
  bulk target stays parked. The datum is *coverage of recognizable names*, not count.

## Story

As **Maya**, I want the artists I already know to be in the collection when I look for
them, so it feels credible rather than arbitrary.
As **Amara**, I want the famous-name fill to arrive without draining the range, so the
pool doesn't become the leader's Euro-canon greatest hits.

## Intake

- **Problem:** the bullets above — a selection gap measured at seven absent names, plus a
  fragmentation gap under it that this story reports and does not fix.
- **Evidence:** gallery tests 2026-08-15/16 (P2, observed); `bin/rails pool:coverage` run
  against the committed manifest and the 2026-08-13/18 mirrors;
  `user-research/0007-recognizable-artists.md`, the mined and pageview-controlled name
  list this story commissions and consumes.
- **Lane:** Full (core). One story, no releases — the split that created it was the
  scope cut.

### Success signal (prediction, falsifiable and time-bound)

1. **By Aug 21**, `bin/rails pool:coverage` reports **≥ 90% reachable coverage** —
   covered ÷ (covered + fillable) over the 0007 list — against the baseline the same task
   measures before the re-curation. Fillable = the name has ≥ 1 mirror work clearing every
   0013 bar. Walled and absent names are outside the denominator: a fill cannot reach
   them, so counting them would make the number permanently red and un-actionable.
   **Measured baseline, 2026-08-19, against the committed 0007 list and the pre-fill
   manifest: 69.5%** — 73 covered of 105 reachable, with 32 names the mirrors hold and the
   pool did not, 21 public-domain-but-not-held, and 74 walled by copyright.
2. **By Aug 21**, Vermeer, Hokusai and Hiroshige each answer **200 with ≥ 1 work** on
   `https://dailytondo.com/artists/:slug` for a signed-in reader. Today all three 404.
3. **By Aug 21**, `pool_quota_test` **asserts** the slug-based per-artist max at
   ≤ `MAX_PER_ARTIST` and is green. Today that assertion would fail at 9
   (`paul-cezanne`) — the E1/X2 defect story 0018 Release 1 could only report.
4. **Range does not regress**: every 0013 bar green at the unchanged TARGET of 2,000,
   non-Western share ≥ 45%, no region over 25%.
5. **No place ships as a painter.** `pool_quota_test` asserts that no artist string which
   is simply a place word resolves to an artist page. Today **49 works over 31 strings**
   do — `/artists/india-calcutta` holds five — and this is the third time this defect has
   been found by hand (0018 E2, then `/qa` ISSUE-001, then this story's own review). The
   assertion is what stops there being a fourth.

**Wrong if:** the fill can only be met by growing TARGET, by relaxing a 0013 bar, or by
pushing non-Western share below 45%. Any of those means recognizable-name coverage and
range are in genuine conflict in these four collections, and the honest answer is to fill
the subset that fits and log the shortfall — not to move a bar.

**Falsification clause (from the seed spec, kept):** if `verify!` raises `Unmeetable` at
every viable configuration, fill the fillable subset that fits, log the shortfall in the
pool report, and this prediction fires for the remainder.

### What this story does NOT move — R7, stated up front

**Zero of five `BET.md` thresholds.** Same finding as X1 against story 0018 and it has
not aged: the binary has never been uploaded (live-by date was **Aug 14**, missed), no
`solid_queue` in the Gemfile and no APNs, so Proven-baseline items 1 and 2 still do not
exist, and nothing here advances the daily pick. Kill review is **12 days out**.

This is a **content-quality** story reached through an app whose front door has held the
same day since Aug 16. Progress under R7 is installs, ranked keywords, published posts and
initiated user conversations — this is none of them. It is worth building because the
pool it fixes is the product, and because the defect it fixes is invisible from inside the
build. It is not worth calling progress.
