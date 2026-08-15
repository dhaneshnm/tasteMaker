# Pre-Build Validation: Interactive Painting-Appreciation Coaching

**Project:** Daily-art app (Month 1, 12-month experiment, Fork B)
**Date:** 2026-08-14
**Method:** YouTube comment mining + willingness-to-pay proxy check
**Status of decision context:** Go decision already made (2026-08-04). This research validates the **differentiator's positioning**, not go/no-go. Kill review remains 2026-08-31 against BET.md thresholds.

---

## 1. Problem statement

### 1.1 The hypothesis under test

Users in the daily-art category will look at paintings for free but will pay for a specific class of higher-level interaction. The proposed interaction: a coached looking experience — keyed observation prompts per painting ("look at this section, notice X, here's why") that helps a layman see a painting more intelligently. Target user is the untrained viewer; trained-art people are explicitly out of scope.

### 1.2 Why validation was needed before build

- The hypothesis is an **interpretation from competitive analysis** (17 apps), not a request from any user. Nobody asked for it.
- n=1 demand exists (Dhanesh himself, stated willingness to pay $2–3/mo). Legitimate grounding for Fork B; not demand evidence.
- Direct customer interviews (4–5 conducted) yielded no signal either way — people cannot evaluate a concept they haven't experienced (Mom Test limitation).
- Category economics on record: total paid revenue plausibly <$500K/yr; leader converts installs at ~$0.05 lifetime. Any new paid-interaction claim starts from a skeptical prior.

### 1.3 The validation question

Is there observable, past-behavior evidence that the audience for "how to look at paintings" content wants the **interactive** version of that job — before any feature code is written?

---

## 2. Evidence framework

Prior reasoning established what different evidence classes can and cannot prove:

| Evidence | Proves | Does not prove |
|---|---|---|
| High views on free close-looking videos | The job ("teach me to see") exists at scale; the register resonates | Willingness to pay; desire for interactivity |
| Passive→interactive precedents (Brilliant vs 3Blue1Brown, chess.com vs chess YouTube, Duolingo vs language YouTube) | The conversion pattern can monetize in other domains | That it transfers to this category |
| Comment mining | What viewers actually do and ask for (past behavior) | Absence of asks ≠ absence of latent demand |
| Patreon supporter counts | Visible payment floor for this exact audience | Ceiling for a different (interactive) offer |

Two proxies were selected as checkable within hours, zero build cost:

1. **Comment mining** on canonical close-looking videos — hunt for (a) viewers attempting the skill, (b) requests for practice/interactive tools.
2. **Patreon membership count** on a leading art-explainer channel — visible willingness-to-pay floor.

---

## 3. Methodology and steps taken

### 3.1 Tooling

- Container environment with `yt-dlp` (comment extraction via `--write-comments`, top-sort, capped per video). `youtube-comment-downloader` was attempted first and failed (API response error); yt-dlp fallback succeeded.
- Python for classification; regex category patterns plus a loose substring sweep as a false-negative check.

### 3.2 Video selection

Videos found via YouTube search on the niche's core queries ("how to look at a painting," "great art explained," "how to analyze a painting art history," etc.). Selection criteria: canonical close-looking content, large view counts, direct overlap with the app's editorial lane (Smarthistory methodology, explainer register).

| Video | Channel | Views | Comments pulled |
|---|---|---|---|
| The Death of Socrates: How To Read A Painting | Nerdwriter1 | 4,385,241 | 1,155 |
| Mona Lisa (Full Length) | Great Art Explained | 2,383,422 | 1,039 |
| How to do visual (formal) analysis in art history | Smarthistory | 1,167,572 | 240 |
| How to Look at an Artwork | Phoenix Art Museum | 227,174 | 125 |
| How to Look at Art: Crash Course Art History #2 | CrashCourse | 190,617 | 108 |
| **Total** | | **8.35M** | **2,667** |

Comments were pulled top-sorted (by engagement), capped ~1,200–1,500 per video.

### 3.3 Classification categories

Each comment was tested against five signal categories:

| Category | What it captures | Example trigger phrases |
|---|---|---|
| **skill_attempt** | Viewer doing the skill or reporting changed perception | "I never noticed," "opened my eyes," "now I see" |
| **wants_more** | Leaning forward, requesting more content | "please do more," "would love to see," "part 2" |
| **wants_interactive** | The product signal: asks for app/tool/practice | "is there an app," "interactive," "quiz," "where can I practice" |
| **pay_signal** | Any payment/support behavior or intent | "I would pay," "patreon," "take my money" |
| **job_statement** | Explicit statement of the underlying job | "learn how to look," "never understood art" |

### 3.4 False-negative check

Because a zero in `wants_interactive` is the load-bearing result, it was re-verified with a loose substring sweep independent of the regex patterns: ` app `, `apps`, `interactive`, `practice`, `quiz`, `exercise`, `flashcard`, `duolingo`, `course`, `where can i learn`, `how can i learn`, `resources`, `recommend`. All hits manually reviewed.

### 3.5 Willingness-to-pay proxy

Web check of Great Art Explained's public Patreon membership count (channel: 1.8M+ subscribers, 2–4M views per video).

---

## 4. Results

### 4.1 Classification counts (2,667 comments)

| Video | skill_attempt | wants_more | wants_interactive | pay_signal | job_statement |
|---|---|---|---|---|---|
| Nerdwriter1 | 2 | 20 | **0** | 5 | 4 |
| Great Art Explained | 6 | 22 | **0** | 4 | 1 |
| Smarthistory | 1 | 1 | **0** | 1 | 5 |
| Phoenix Art Museum | 1 | 0 | **0** | 1 | 1 |
| CrashCourse | 0 | 3 | **0** | 0 | 1 |
| **Total** | **10** | **46** | **0** | **11** | **12** |

### 4.2 The zero, verified

Loose sweep results: ` app ` = 0, `apps` = 0, `interactive` = 0, `quiz` = 0, `flashcard` = 0, `duolingo` = 0, `where/how can i learn` = 0. `practice` = 3 (none tool-seeking; one is Smarthistory's own top comment saying looking takes practice — 111 likes). `course` = 30 (nearly all "of course" or school courses; one real signal, below). Not a regex artifact.

### 4.3 Representative evidence (confirmed, verbatim from scraped data)

**The job, stated unprompted:**
- "Where do you go or what do you do to learn how to interpret at this level. How does one learn to see the deeper meaning, without being told. I feel I could have stared at this painting for a decade and never come away with it…" (Nerdwriter)
- "This just made me realize that I have absolutely no idea how to look at art" (Nerdwriter)
- "As someone who loves but does not understand art, I learned more in six minutes… than I have in the last six months" (Phoenix Art Museum, 137 likes)

**The outcome the feature intends to produce, already occurring from passive video:**
- "I never noticed that she doesn't have eyebrows. That's all I can look at now." (Great Art Explained)
- "This just opened my eyes on how to view things." (Smarthistory)

**Demand, as actually expressed — more passive content:**
- "Please do more of these!! But maybe with some other type of paintings? Surrealism?" (Nerdwriter)
- 46 total asks for more videos; top ask has 226 likes.

**Payment, as actually expressed — creator-attached:**
- "I would pay for an art history course by Nerd Writer" (15 likes). Strongest pay signal in the dataset; parasocial, not category-level.

### 4.4 Willingness-to-pay proxy (confirmed)

Great Art Explained: **380 paid Patreon members at $6/month** (~$2.3K/mo gross) against a 1.8M-subscriber channel with multi-million-view videos. Conversion of this audience from free viewing to any payment: roughly 0.02% of subscribers. Consistent with the on-record category finding (~$0.05 per lifetime install for DailyArt).

---

## 5. Conclusion

### 5.1 What is proved

1. **The job exists and is articulated at scale.** Viewers state "I don't know how to look at art" and "where do I learn to interpret at this level" unprompted. The gap between wanting to see and knowing how is real, felt, and expressed in the audience's own words.
2. **The register is validated.** Smarthistory/explainer-style close looking draws millions of viewers; the Berger/Walsh lane resonates beyond trained-art audiences.
3. **The target outcome occurs.** Passive video already produces qualitative noticing reports — the exact success signal defined for the coaching feature. Structured prompts betting on producing it more reliably is a plausible, not fanciful, mechanism.

### 5.2 What is not found

4. **Zero expressed demand for the interactive version.** 0 of 2,667 comments ask for an app, tool, quiz, or practice format. Demand is voiced exclusively as *more passive content*.
5. **Willingness to pay is confirmed tiny and parasocial.** The audience pays (rarely) to support creators, not to acquire capability.

### 5.3 Interpretation

The absence of interactive asks is **expected, not fatal** — people do not request products that don't exist (nobody asked 3Blue1Brown's comments for Brilliant). But it changes the honest status of the hypothesis:

> **This is a latent-demand bet, not an expressed-demand gap.** The gap was inferred from competitive analysis; the market has not voiced it. The category's only expressed demands are more passive content and creator support.

### 5.4 Consequences for the project

- **Fork B absorbs this cleanly.** The feature stands as the New-slot differentiator (nobody occupies it; register validated), and the hand-keyed observation bank doubles as editorial content regardless of feature uptake.
- **Intake card wrong-if line (to be recorded):** *Expressed demand for interactivity = 0 in 2,667 comments across 8.35M views. The bet is that demand is latent and surfaces on contact. Falsified if beta users neither engage with keyed prompts nor report improved noticing by 2026-08-31.*
- **Positioning language acquired.** The audience's own words — "learn how to look," "I never noticed," "opened my eyes" — are the ASO and landing-page vocabulary. "Interactive" is not their word; do not lead with it.
- **No pricing update.** Nothing here supports pricing above the category floor (~$30/yr); nothing requires pricing below it.

### 5.5 Limitations

- English-language comments only; top-sorted (engagement-biased toward praise); capped per video; 5 videos.
- Comment sections systematically undercount tool-seeking behavior — people ask Google/App Store, not YouTube comments. The zero is a true zero *in this venue*, not a measured zero in the population.
- Patreon count is one channel, one snapshot; supporter counts on other art-explainer channels not yet checked.

---

## Appendix: Reproduction

- Extraction: `yt-dlp --skip-download --write-comments --extractor-args "youtube:comment_sort=top;max_comments=1500,all,100" <url>`
- Raw data: `c_<video_id>.info.json` per video; classification in `analyze.py`; counts in `summary.json`.
- Videos: rKhfFBbVtFg, ElWG0_kjy_Y, sM2MOyonDsY, AZoKElBwKCs, YHcX_nuyQPc.
