# 0009 — Implementation plan

Status: **Implemented 2026-08-07.** Design review skipped (see below). Eng review not run.

## Approach

Twelve `woff2` files, one `@font-face` block, three deleted lines, two licence texts, one
test file. No gem, no build step, no change to the type scale or the token table.

The whole story is one question — *where do the bytes come from* — and the answer that
makes it safe is: **the same bytes**. Google's CDN was already serving latin, latin-ext and
vietnamese subsets of both families. Those exact files now sit in `app/assets/fonts/`. A
story whose spec says "a visual diff is a failure, not a bonus" is best served by making a
visual diff arithmetically impossible rather than by re-subsetting and hoping.

## Decision 1 — Google's own subset files, unmodified

The spec anticipated a subsetting job: latin-only, `SOFT` and `WONK` pinned, to fit 250 KB.
Measured on this checkout 2026-08-07, that job is already done in the files the CDN serves.
`fontTools` reports each downloaded file carries exactly two axes:

```
fraunces-roman-latin.woff2      glyphs=245  axes=[opsz 9–144, wght 100–900]
newsreader-roman-latin.woff2    glyphs=262  axes=[wght 200–800, opsz 6–72]
```

`SOFT` and `WONK` are already gone. Nothing left to pin.

**Re-subsetting was tried and rejected.** Clipping the `wght` axis to the ranges the
existing `<link>` requested (Fraunces 300–700, Newsreader 300–600) via
`fontTools.varLib.instancer` saved **22 KB out of 424 KB — 5%** — and cost a build step
whose output no test can prove is visually identical to what production served yesterday.
Not worth it. The instancing script is not committed; it exists only in this session's
scratchpad and is not needed to reproduce the result.

**Neither axis is pinned.** `opsz` is set explicitly at 60 (`.masthead__brand`) and 100
(`.label__title`), but the CSS default `font-optical-sizing: auto` means `opsz` also tracks
font-size on *every other element* — so the full 9–144 and 6–72 ranges are live and
clipping them would be a real regression, not an optimisation.

## Decision 2 — three subsets, not one

The spec budgeted latin only. That would have been a silent content bug.

`db/seeds/mia_paintings.json` — the real MIA data, not fixtures — contains **ā č ō ū ž ȟ ŋ ƞ**
in artist and title fields. Every one of those is latin-ext (U+0100–02BA), outside the latin
subset. Shipping latin alone drops those names mid-word into Georgia, on exactly the
non-Euro-canon curation `CLAUDE.md`'s Better bucket item 6 asks for.

Vietnamese is included for the same reason at 97 KB: MIA's Asian collection is in scope for
this product, and `unicode-range` means a reader who never sees a Vietnamese name never
downloads a byte of it.

**CJK is unchanged and unfixed.** The same seed file carries 佛 性 成 盛 秀 見. Neither
family ships CJK glyphs and the CDN never served any, so those titles fall back to a system
face today and still do. Naming it here so nobody reads this story as having covered it.

## Decision 3 — the prediction was wrong on size, and here is the real number

The spec predicted **≤ 250 KB** added repo weight and said, if that could not be met, to
record the real number rather than drop an axis the design depends on. Taking it at its
word:

| | Files | Bytes |
|---|---|---|
| latin | 4 | 428,000 |
| latin-ext | 4 | 313,148 |
| vietnamese | 4 | 97,136 |
| **Total repo weight** | **12** | **838,284 (819 KB)** |

**Prediction revised: 819 KB, 3.3× the budget.** The budget was written against a
latin-only, single-subset guess and did not survive contact with the axes or the data.

What the budget was *trying* to protect — the reader's connection — is unharmed, and this
is the number that actually matters:

- **Bytes on the wire are unchanged.** The CDN was serving these same subset files. A page
  that pulls all four latin faces pulled 418 KB yesterday and pulls 418 KB today.
- **`unicode-range` gates the rest.** latin-ext and vietnamese are fetched only by a page
  that contains those characters. Most days: zero.
- **Two hosts, two DNS lookups and two TLS handshakes are gone** from the critical path,
  which was the actual problem the story was opened to fix.

819 KB of repo is 819 KB of git, not of anyone's morning tea.

## Decision 4 — no `<link rel="preload">`

Self-hosting moves font discovery from "after an external stylesheet parses" to "after our
own stylesheet parses" — strictly earlier than before, on strictly fewer connections. A
preload would move it earlier still, but it is a performance change, not a sourcing change,
and the spec's scope section says this story changes where the fonts come from **and
nothing else**. Out.

## Files

| File | Change |
|---|---|
| `app/assets/fonts/*.woff2` | new — 12 files |
| `app/assets/fonts/OFL-{Fraunces,Newsreader}.txt` | new — licence travels with the files |
| `app/assets/stylesheets/application.css` | 12 `@font-face` rules + the why, above `:root` |
| `app/views/layouts/_head.html.erb` | 3 lines deleted, replaced by a comment pointing at the test |
| `test/integration/self_hosted_fonts_test.rb` | new — the forcing function |

Propshaft needed no configuration: `app/assets/fonts` is picked up automatically because
Rails globs every subdirectory of `app/assets` into the load path (verified — it appears
first in `config.assets.paths`). `url("fraunces-roman-latin.woff2")` resolves through
`Propshaft::Compiler::CssAssetUrls` to a digested path.

## Forcing function (R1)

`test/integration/self_hosted_fonts_test.rb`, six tests:

1. No reader-facing page (`/`, `/days`, `/feed`, `/nope`) names either font host.
2. The admin layout does not either — it is the one layout with a different `<head>`.
3. **The general rule:** no `<link href>` or `<script src>` on any reader-facing page
   points at another host. This is wider than the story on purpose. A tag manager or an
   icon CDN breaks the same property, and story 0008's offline error screen cannot fetch
   anything it does not have.
4. The stylesheet serves exactly 12 distinct `woff2` faces and every one resolves 200.
   The count is asserted because losing latin-ext is the failure that hides — it surfaces
   only on the artist names carrying ā, č, ō, ū, ž or ȟ.
5. Both families keep a `font-weight` **range**, which is what proves the files are still
   variable. A static substitution would flatten `opsz` — a visual regression wearing an
   optimisation's clothes.
6. The OFL text ships with the fonts. A licence obligation with no check is a wish.

**Correction to the spec.** Story 0009 says `test/system/design_test.rb` "already measures
`bodyFont` and `brandFont` and fails on drift, which catches a fallback to Georgia." It does
not. `getComputedStyle(el).fontFamily` returns the **declared** stack —
`"Fraunces", "Iowan Old Style", Georgia, serif` — byte for byte identical whether Fraunces
loaded or the browser fell straight through to Georgia. That test would have passed against
a completely broken font setup.

So `test/system/fonts_test.rb` is new, and it asks the font system instead of the cascade:
after `document.fonts.ready`, it asserts `document.fonts.check()` for both families and
that the set of *loaded* families is exactly `["Fraunces", "Newsreader"]`. If the faces had
not loaded, that set would be empty. `design_test.rb` is unchanged — it is a good one-skin
check, it was just never the anti-Georgia check.

## Deviation found while implementing

**`public/assets` held a stale precompiled build** that shadowed the source stylesheet in
the test environment — the served CSS was the pre-edit 20,865-byte file while the source on
disk was 26,758 bytes. Propshaft serves from `public/assets/.manifest.json` when it exists,
and that directory is gitignored, so the staleness was invisible to git and to CI.
`bin/rails assets:clobber` cleared it.

Worth knowing rather than fixing here: any local checkout that has ever run
`assets:precompile` will serve stale CSS until it is clobbered. This is a local-environment
trap, not a defect in the app, and inventing a guard for it now would be infrastructure for
later.

## Design review — skipped, and why

`/plan-design-review` is for features with significant UI. This story's success condition is
that **nothing changes visually**. There is no new surface, no new token, no new type scale
— the review would be reviewing an intentional no-op. Skip noted per build flow step 3.

The design question that did exist — whether dropping latin-ext was acceptable — was
answered against the seed data in Decision 2 rather than against taste.

## Not done

- `/plan-eng-review` (build flow step 4) has not been run on this plan.
- Content Security Policy. Self-hosting is what makes `font-src 'self'` possible;
  `config/initializers/content_security_policy.rb` is still entirely commented out and
  writing that policy is its own decision.
- Bundling these files into the iOS app target — story 0008's error view, which now has a
  local source to copy from.
