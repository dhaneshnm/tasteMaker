# 0020 — Keep where you find it · implementation plan
Status: **Reviewed** — `/plan-design-review` and `/plan-eng-review` both clear, 2026-08-19.
Blocked on: nothing. The coverage fill shipped as `specs/0019-the-coverage-fill`, so the
WIP slot is free and this is next.

## Approach

Add the keep control to the one partial both walled multi-work surfaces share, and render
it **inline and server-side** rather than as a fetching Turbo frame.

That last clause is the whole plan. Everything else follows from it.

Touched: `app/views/paintings/_painting.html.erb`, `app/views/favorites/_control.html.erb`,
`app/controllers/paintings_controller.rb`, `app/controllers/artists_controller.rb`,
`app/controllers/favorites_controller.rb`, `app/views/artists/show.html.erb`,
`app/views/paintings/_page.html.erb`, one CSS selector. No new model, no new route, no new
partial, no JavaScript.

### The constraint that does NOT apply here, and why that changes everything

`/`'s keep control is a `turbo_frame_tag` with a `src` that fetches
`/collection/:id/control` on every page view. That architecture exists for exactly one
reason, written down in three places (`favorites_controller.rb:1-19`,
`daily/_day.html.erb:108-118`, `favorites/_control.html.erb:8-15`): **`/` is
`Cache-Control: public` behind Thruster.** A `button_to` mints a CSRF token, a token starts
a session, a session puts `Set-Cookie` on a body a shared cache serves to everyone. Story
0007 drew that line; `public_cache_headers_test.rb` holds it.

**`/feed` and `/artists/:slug` are not public.** Both inherit `require_reader` with no
skip, and story 0015 made them `private` — `public_cache_headers_test.rb:11` says so in as
many words, and `PUBLIC_PAGES` there is `%w[/ /privacy /support]`. There is no shared cache
to poison and no byte-identical body to protect. The reader already carries a session or
device cookie just to be on the page.

So on these two surfaces the frame does not need a `src`. Render the real `button_to` into
the page. The frame tag stays — it is what makes the write a fragment swap instead of a
navigation — but it arrives with its contents already in it.

| | `/` (public) | `/feed`, `/artists/:slug` (walled, private) |
|---|---|---|
| Frame | `src:` → eager fetch | no `src`, contents inline |
| Extra HTTP requests | 1 | **0** |
| Extra queries | 2 (exists? + count) | **1** per page, for all N works |
| Placeholder glyph | needed (covers the fetch) | not needed (no fetch) |
| Write behaviour | frame swap | frame swap (identical) |

Ten works on a feed page cost **one** `WHERE painting_id IN (...)` against the leading
column of the favorites unique index. Not ten requests, not twenty queries.

### Alternatives considered and rejected

- **Copy `/` verbatim — eager frames with `src`.** 10 HTTP requests and 20 aggregate
  queries per feed page; 110 requests to walk the gallery. Rejected on cost, and the cost
  buys nothing because the constraint that justifies it on `/` is absent here.
- **Lazy frames (`loading: :lazy`).** Fewer requests, but every mark visibly flips from
  outline to filled as the reader scrolls past — the exact "empty hole where the habit
  mechanic should be" that `daily/_day.html.erb:103-107` refuses, moved onto a screen that
  shows ten of them. Rejected.
- **Batched endpoint + Turbo Stream fan-out** (`GET /collection/controls?ids=…` replying
  with N `<turbo-stream replace>`). One request instead of ten — but it needs a new route,
  a new template, and something client-side to fire it. Machinery for a problem inline
  rendering deletes. Rejected as infrastructure-for-later.
- **Plain inline `button_to` with no frame at all.** Turbo Drive refuses a 200 for a
  form outside a frame — *"Form responses must redirect to another location"*, the exact
  wart `favorites_controller.rb:104-118` already documents. Every keep would become a full
  navigation, which on `/feed` throws away the scroll position and every lazily-loaded
  page below it. **The frame is not optional; only its `src` is.**

## The shared partial gets one new local

`favorites/_control.html.erb` takes `painting, kept, count, autofocus`. Add **`compact:`**
(default `false`).

`compact: true` suppresses the `"N kept"` link (`_control.html.erb:52-55`) and nothing
else. Reason in `story.md` non-goals: ten copies of `3 kept` down one scroll is noise, and
the compass carries `Kept` on every screen already. The mark still carries its full
`aria-label` ("Keep *title* in your collection"), so the accessible name is unchanged —
this drops a redundant visible word, not an announcement.

**The write path has to know too.** `FavoritesController#create`/`#destroy` re-render the
partial into the frame; without `compact` the count link would appear under one work on
the feed the moment it is kept. Carry it on the form:

- `_control.html.erb`: `button_to … params: (compact ? { compact: "1" } : {})`
- `favorites_controller.rb`: `render_control(compact: params[:compact].present?)`

Explicit hidden field, not inference from the `Turbo-Frame` header or the referer. The
frame id is `keep_<id>` on every surface and the referer is not a contract.

## Controller shape

**One method, in `ApplicationController`, next to `reader_favorites`** — not two copies in
two controllers. Corrected by `/plan-eng-review` (CQ1): the plan originally wrote the same
two lines into `PaintingsController` and `ArtistsController`, and this codebase has already
argued that exact case in `application_controller.rb:135-139`, when `/you` became the second
caller of `reader_favorites`:

> Two copies of "this reader's kept works" is one copy too many: the day they drift, `/you`
> shows a number that disagrees with `/collection`.

```ruby
# ApplicationController, private
def kept_ids_for(paintings)
  reader_favorites.where(painting: paintings).pluck(:painting_id).to_set
end
```

Each controller calls it once, after `@paintings` is built. No `identified?` guard: both
are behind `require_reader` with no skip, so an identity always exists here — the same
reasoning `favorites_controller.rb:157-161` states for its own actions. If either ever
skips the wall, that guard becomes required and `wall_test.rb` is what will say so.

**Measured, not assumed** (`/plan-eng-review`, EXPLAIN QUERY PLAN against a replica of the
shipped schema):

```
device world   SEARCH favorites USING COVERING INDEX
               index_favorites_on_collector_digest_and_painting_id (collector_digest=? AND painting_id=?)
account world  SEARCH favorites USING COVERING INDEX
               index_favorites_on_user_id_and_painting_id (user_id=? AND painting_id=?)
```

**Covering** in both worlds — index-only, no table access, ten point probes. The account
world's index is partial (`WHERE user_id IS NOT NULL`, `db/schema.rb:69`) and SQLite still
picks it, which was the one thing worth checking rather than assuming. Cost is independent
of how large the reader's collection is.

Passed to the collection render as a local, not read from an ivar in the partial:

```erb
<%= render partial: "paintings/painting", collection: @paintings,
      locals: { kept_ids: @kept_ids } %>
```

**`kept_ids` is a required local, not a defaulted one** (CQ3). `_painting.html.erb:10` uses
`local_assigns.fetch(:show_artist, true)`, and copying that idiom here would be wrong: a
caller that forgets `kept_ids` would silently render every mark un-kept. A wrong mark is
the exact failure this design exists to prevent, and it is worse than a raised error. Bare
`kept_ids`, so a missing local is loud.

`/feed`'s pagination is lazy frames pointing back at `PaintingsController#index`
(`paintings/_page.html.erb:5`), so each page computes its own set for its own ten works.
No change to that mechanism.

### While in `PaintingsController#index` — one pre-existing waste, fixed in passing

```ruby
@next_page = @page + 1 if Painting.count > offset + PER_PAGE   # :8
@total = Painting.count                                        # :9
```

Two identical `COUNT(*)` per request, on every feed page load including all eleven lazy
pagination fetches. Not introduced by this story; found by `/plan-eng-review` in a file the
story already edits, and this is a solo repo. Assign `@total` first and compare against it.
One line, no behaviour change.

## Freshness — the middleware already solved this

**Rewritten by `/plan-eng-review` (A1). The first two drafts of this section were both
wrong, in opposite directions, and the correction is the load-bearing finding of the
review.** Draft 1 added a reader fingerprint to the artist page's ETag. Draft 2 (`/simplify`
direction, approved as D1-A) replaced both with `no_store`. Neither was necessary and the
second was actively worse.

`rack-3.2.6/lib/rack/etag.rb`:

```ruby
def skip_caching?(headers)
  headers.key?(ETAG_STRING) || headers.key?('last-modified')
end
```

`Rack::ETag` sets a **SHA256 digest of the response body** on every 200, skipping only when
an ETag or `Last-Modified` is already present. Not on `no-cache`, not on `private`. Both
halves are live in this app's stack:

```
Rack::ConditionalGet
Rack::ETag
```

A body digest is **inherently per-reader-correct**: the kept marks are in the body, so a
reader who keeps a work gets a different digest and therefore a 200. There is no staleness
class to defend against — the thing draft 1 built a fingerprint for, and draft 2 reached
for `no_store` over, is already handled one layer down.

### What this story actually does about freshness

**`/feed` — nothing.** It rides Rails' default `max-age=0, private, must-revalidate` and
already gets a correct body-digest ETag from the middleware. `no_store` would not buy
correctness it already has; it would discard working 304s and disable bfcache. Zero lines.

**`/artists/:slug` — delete `stale?` and its two aggregates.** `private_revalidate` stays
(`no-cache, private` — a gated body must not sit in a shared cache). With `stale?` gone,
`skip_caching?` is false, so Rack::ETag supplies the body digest and `Rack::ConditionalGet`
still answers a repeat visit with a 304. The network 304 survives; only the manual ETag and
its `count, latest` query go.

**What is genuinely given up, stated plainly.** `artists_controller.rb:29` bails before
`with_attached_image` loads attachments and blobs — a point two 0018 reviews raised
(E-A2/E-A3). That server-side skip is gone: the body must now be rendered to be digested.
On a page bounded at 9 works this is the right trade, and it reverses a shipped 0018
decision, so it is recorded here rather than done quietly.

**This reasoning is held by a test, not by trust** (Test 8, and the regression rule fires on
it): keep a work on an artist page, re-request with the prior ETag, assert **200 with the
filled mark**. If the read of Rack::ETag above is wrong, that test fails and says so.

## CSS — one selector, and it is a design decision

`application.css:596`:

```css
.page:has(.rail) .plate__img { --rail-reserve: var(--tap); }
```

Page-scoped, from when exactly one screen had exactly one rail. Change to plate-scoped,
pairing with the rule already on the next line:

```css
.plate:has(+ .rail) .plate__img { --rail-reserve: var(--tap); }
```

Same idiom as `.plate:has(+ .rail) { margin-bottom: 0.5rem; }` at `:601` — one selector,
two declarations, the picture pays the reserve exactly when a rail actually follows it.
The comment at `:578-582` currently says *"`.plate__img` is also every work in `/feed`,
which renders no rail"*. That sentence becomes false with this story and must be rewritten
in the same commit, not left to rot.

**The consequence, stated for design review rather than assumed:** every plate on `/feed`
and `/artists/:slug` now pays `--rail-reserve`. Using the arithmetic already in that
comment — the term only bites where `calc(100dvh - 19rem - reserve)` is below `55vh`:

- **402×874** — 526px vs 481px, `min()` still picks 55vh. **No change.**
- **375×667** — 319px vs 367px. Feed and artist-page images lose **44px of 363**.

The trade is the same one `/` accepted on 2026-08-14 (rule 2 allows a smaller picture,
never a cropped one), applied to two more screens. It is a real visual change on the small
phone and it is what `/plan-design-review` is for. **The story does not ship without that
review** (CLAUDE.md build flow step 3 — this is not a UI-light story).

`.rail { display: flex; align-items: center; gap: 0.5rem; }` (`:1069`) needs nothing: a
one-child rail sits left-aligned under the plate, which is where the two-child rail's
first glyph sits on `/`. No new rule.

## Nested frames — settled by reading Turbo, not by testing it

`paintings/_page.html.erb:1` is `turbo_frame_tag "feed-page-#{page}", target: "_top"`, and
the new `keep_<id>` frame is **nested inside it**. The first draft of this plan called this
the risk that decides whether the design works, and ordered a red-first gate test with a
"stop and reopen the design" clause.

**Resolved by `/plan-eng-review` — read the shipped `turbo-rails 2.0.23` bundle:**

```js
willSubmitForm(e,t){ return e.closest("turbo-frame") == this.element && this.#_(e,t) }
```

A frame intercepts a form only when it is that form's **closest** `turbo-frame`. The keep
button's closest frame is `keep_<id>`, so `feed-page-N` never gets a vote and its
`target="_top"` is irrelevant. The target resolver confirms it from the other side —
`data-turbo-frame` on the element, else the frame's own `target`, else the frame's `id` —
and `keep_<id>` has no `target`, so it resolves to itself.

The system test stays as a **regression guard**, not a gate: nothing shipped today nests a
frame this way, so nothing else would catch a Turbo upgrade changing it. The "stop and
reopen the design" clause is deleted. If it ever did fail, the one-attribute fallback is
`data: { turbo_frame: "keep_#{painting.id}" }` on the form — the idiom
`_control.html.erb:53` already uses in the other direction for the count link.

## Screen spec — the post, on both surfaces

Added by `/plan-design-review`, 2026-08-19 (D1). The plan described controllers and
frames and never once said what the reader sees.

```
  ┌─ article.post ────────────────────────────┐
  │  figure.plate                             │   1st — the work. Tap = zoom.
  │    button.plate__zoom > img.plate__img    │      55vh cap, now less --rail-reserve
  │    (or p.plate__resting when the CDN 404s)│
  ├───────────────────────────────────────────┤
  │  div.rail            ← NEW, this story    │   2nd — the one act. 44px, --gold,
  │    turbo-frame#keep_<id>                  │      left-grouped, no src.
  │      form.rail__form > button.rail__act   │
  ├───────────────────────────────────────────┤
  │  div.label                                │   3rd — who and what.
  │    h2.label__title                        │
  │    p.label__artist   (feed only; the      │
  │                       artist page passes  │
  │                       show_artist: false) │
  │    p.label__meta / .label__body / __credit│
  │  .label::after  ── the hairline divider   │
  └───────────────────────────────────────────┘
```

Hierarchy is unchanged from `/` and fixed by DESIGN.md:269 — the rail is *directly under
the plate, above the wall label*. Constraint-worship check: if only three things could
show, they are the picture, the act, and the title. That is what a post is now.

**The rhythm cost, named rather than discovered.** `/feed` is the product's only unbounded
screen (DESIGN.md rule 5). A gold glyph now sits between every picture and its title,
**110 times** down one scroll, and each post grows by `--tap` + `.rail`'s `0.75rem` bottom
margin ≈ 56px — roughly 6,200px of added scroll over the full gallery. This is accepted,
not overlooked: the glyph is the reason the screen exists to be scrolled, and DESIGN.md's
`.post` entry gains a line saying a post may carry a rail.

## Interaction states

| State | `/` today | `/feed` + `/artists/:slug` — what the reader SEES |
|---|---|---|
| **Loading** | outline glyph, then it may fill when the fetch lands | **none — there is no fetch.** The mark is correct in the first paint. This is the design's best property and it belongs in the table, not in a cost table. |
| **Resting (image 404s)** | rail still renders; keep survives, zoom hides | identical. `.plate__resting` note, **rail unconditional** — a resting work is still a work you can keep (`daily/_day.html.erb:78-80`). No preview mode here, no zoom child, so no state reaches an empty rail. |
| **Un-kept** | outline bookmark, `--gold` | same glyph, same token. |
| **Kept** | filled bookmark, no colour shift | same. DESIGN.md:315-319 — filled *is* the kept state. |
| **Mid-submit** | button stays drawn until the frame swaps | same. No spinner, no disabled state: the swap is one round trip on a walled page, and rule 7 allows a fade, not a spinner. A double-tap is already absorbed (`favorites_controller.rb:81-92`). |
| **Error — identity died mid-scroll** | n/a | the mark is replaced **in place** by a `Sign in` caps-link that breaks out to `/you` (`application_controller.rb:95-102`). Not "Content missing", not a silent hole. Already built; this story asserts it. |
| **Empty** | n/a | **no new empty state.** `/feed` page 1 always has works; `/artists/:slug` 404s at zero (`artists_controller.rb:25`). Nothing to design. |

## User journey — Tomás, the reader this is for

| Step | He does | He feels | What the plan gives him |
|---|---|---|---|
| 1 | Taps an artist name on `/days/2026-08-12` | curious — "what else?" | 0018's artist page |
| 2 | Lands on `/artists/hokusai`, 7 works | recognition, a small thrill | masthead aside says `7 works` |
| 3 | Sees one he wants | **wants to act, now** | **this story: the mark is right there** |
| 4 | Taps it | the mark fills, page does not move | inline frame swap, scroll position held |
| 5 | Taps two more | building something | three filled marks |
| 6 | Wonders where they went | **the gap** | compass `KEPT` in the masthead — one tap, on screen the whole time |

Time horizons: **5 seconds** — the mark is drawn correctly in the first paint, no flicker
(the inline design's whole point). **5 minutes** — keeping is one tap from anywhere he
finds a work, not two screens. **5 years** — this is Jordan's catalogue, and it is
buildable from every surface that shows a whole artwork, which is the outcome that makes
it a catalogue rather than a curator's log.

Step 6 is the honest weak point and it is what design decision D2 below settles.

## Responsive & accessibility

**375×667 (iPhone SE, the device `dynamic_type_test.rb` measures and persona 2 holds).**
`--rail-reserve` applies, so `calc(100dvh - 19rem - 44px)` = 319px beats `55vh` = 367px:
height-capped works lose **44px of 363**. This is the identical trade `decisions/0010:39-43`
accepted for `/` and `/days/:date` on the same device, and rule 2 already allows it — *a
smaller picture, never a cropped one*. It bites only works tall enough to be height-capped;
landscape works do not move.

**402×874 (iPhone 17 Pro).** `calc` gives 526px against `55vh` = 481px, so `min()` still
picks `55vh`. **Free — no change at all.**

**Desktop / `--measure` 42.5rem.** `.rail` is left-grouped (`justify-content` default,
`flex-start`), one child, sitting under the plate's left edge. DESIGN.md:310-313 refuses
spreading; with a single item there is nothing to spread.

**Keyboard.** Tab stops per feed page go **20 → 30** (plate zoom, keep, artist link × 10).
Accepted: every added stop is a control the reader asked for, and the pagination sentinel
is a lazy frame rather than a focusable element. No skip-link is added — `/feed` has the
sticky `.compass--rail` above the works, which is the way out rule 5 already bought.

**Focus after a write.** `autofocus: true` on write responses only, `false` on initial
render — already the contract (`favorites/_control.html.erb:19-25`). With ten frames on a
page this matters more, not less: Turbo destroys the focused button on swap and focus would
drop to `<body>`, losing the reader's place in a 110-work scroll. The autofocus puts it
back on the mark they just pressed, which is also what makes a screen reader announce the
new state.

**Screen readers.** Ten marks on a page are distinguished by name, not position: each
carries `Keep <title> in your collection` / `Remove <title> from your collection`
(`favorites/_control.html.erb:36-39`), plus `aria-pressed`. No `aria-live` — a fragment
arriving unbidden must not announce itself; focus landing on the toggle does that job.

**Touch targets.** 44px in **both** axes. Rule 9's second-axis clause exists for exactly
this control: a bare glyph has no words, so `.rail__act` states `min-width` as well as
`min-height`, both reading `--tap`. No new CSS — the class already does it.

**Contrast.** `--gold` `#7d5f18` on `--bg` `#f4efe6` = 5.3:1, above the 3:1 WCAG 1.4.11
asks of a graphical object. Unchanged, measured in DESIGN.md's token table.

**Reduced motion.** Nothing added. `.post.reveal-init` fade is the existing scroll-in and
is already gated; a frame swap is not an animation.

## DESIGN.md amendments owed (R1 — the doc IS the enforcement)

DESIGN.md:4-5: *"When something new gets built, it reuses these; a new visual idiom needs a
line in this file saying why."* This story contradicts three written statements. Each gets a
line in the same commit, or the file starts lying:

1. **`.rail` = "Zoom, then Keep, then the count"** (DESIGN.md:271). On `/feed` and
   `/artists/:slug` it is **Keep alone**. Zoom is dropped because the plate is already the
   zoom trigger there and a second control for one action would be a duplicate tab stop —
   the same reasoning `decisions/0010:51-54` used to *add* zoom on `/`, where the plate
   competes with a wall label for the reader's attention.
2. **"The frame ships default content"** (DESIGN.md:280-285). True on `/` and only on `/`.
   The walled surfaces ship the *real* control, because the public-cache constraint that
   forces the split does not exist there. The paragraph needs the scope named, or the next
   reader will "fix" the walled surfaces back into fetching frames.
3. **The −44px trade** (DESIGN.md:321-329) is written as a fact about `/` and `/days/:date`.
   Widen the screen list. **Rule 2 itself needs no change** — it already reads
   *"`--rail-reserve` is `0` everywhere except the screens carrying an action rail"*, which
   is general and stays true.
4. **"The count keeps its word"** (DESIGN.md:300-302) — added by **D1**, below. The count
   is scoped to `/` and `/days/:date`; the walled multi-work surfaces are mark-only. This
   one also needs a line in `decisions/0010`, because it narrows a mitigation that decision
   bought a documented risk with — see D1.

## Design decisions — `/plan-design-review`, 2026-08-19

### D1 — mark-only on multi-work surfaces, and the debt is written down

**Decided: mark-only.** No `"N kept"` on `/feed` or `/artists/:slug`.

The plan originally filed this as a self-evident non-goal ("ten copies of `3 kept` is
noise"). That framing was wrong and the review caught it. `decisions/0010:98-104` bought
the label-less rail against explicit contrary evidence — NN/g measures unlabelled
app-specific icons at **34% correct prediction**, and the recommendation on the table was
icon-plus-caps-label. It was overruled for the quieter row, and the price was paid with
**two** named mitigations:

> The mitigations are the count keeping its word — `3 kept`, not `3`, the only word left in
> the rail and the one free piece of literacy on it — and accessible names on every glyph.
> **If a reader misreads a glyph in the five `BET.md` conversations, this is the line that
> was wrong and labels are the fix already costed.**

Mark-only deletes the first mitigation on the two surfaces where a reader *discovers* work.
That is a real cost and it is taken deliberately, for one reason: **literacy is taught once,
on the surface every reader opens every day.** `/` is that surface by construction — it is
the push destination, the front door, and the only unwalled one. A reader cannot reach
`/feed` or `/artists/:slug` at all without an identity, and the ordinary route to an
identity runs through `/`. The count teaches the glyph there, once, with a word.

What survives intact on the new surfaces: the second mitigation in full — every mark
carries `Keep <title> in your collection` / `Remove <title> from your collection` and
`aria-pressed` (`favorites/_control.html.erb:36-39`) — plus `/collection`'s empty state,
which is the one place in the product that names the shape in prose: *"The bookmark under
each artwork keeps it here."*

**Rejected: count under the first work only.** It is the obvious middle and it does not
work. Keeping work #7 returns only `keep_7`'s frame, so a count rendered inside `keep_1`
goes visibly stale — a wrong number on screen, which is worse than no number. Correcting it
needs a Turbo Stream touching two frames per write, which is the machinery this design
exists to delete.

**The tripwire, restated so it is falsifiable.** If a reader in the five `BET.md`
conversations misreads the bookmark on `/feed` or an artist page, **this decision is the
line that was wrong**, and the fix is the one `decisions/0010` already costed: labels.
Not a redesign.

### D2 — both surfaces, not the artist page alone

**Decided: `/feed` and `/artists/:slug` together.**

The alternative was real and was considered: ship the artist page only, leave the product's
one unbounded screen untouched, defer `/feed` to `IDEAS.md` pending a gallery run. It is
the more conservative call 12 days from kill review, and `/feed` carries the rhythm cost
(110 glyphs, ~6,200px of added scroll) on design-review inference with no user observation
behind it.

Rejected because the deferral costs *more code, not less*. The two surfaces share one
partial (`paintings/_painting.html.erb`); doing both is the absence of a branch, while
doing one requires a surface-conditional local threaded through the shared partial and
tested in both directions. And the story's claim is a baseline-completeness claim —
favorites wired on 2 of 4 work-showing surfaces. Closing it to 3 of 4 leaves a queue entry
nobody may pick up and a story whose own success signal it no longer satisfies.

The rhythm cost is accepted and now written into the screen spec above rather than
discovered at QA.

## Failure modes — one realistic production failure each

- **Identity dies mid-scroll** (signed out elsewhere, device revoked). The keep frames
  carry no `src`, so nothing fetches; but a *write* is a frame request and hits
  `require_reader`, which answers with a matching frame holding a "Sign in" link
  (`application_controller.rb:95-102`). The reader sees the mark replaced by a way back
  instead of "Content missing". Already designed for; add the assertion, do not add code.
- **Two tabs, same work.** `Favorite.create!` raises `RecordNotUnique`/`RecordInvalid` and
  `favorites_controller.rb:81-92` already treats it as success. Unchanged — a feed keep
  and a front-door keep of the same work go through the identical action.
- **A work on the feed whose image 404s from the museum CDN.** `display_image?` is false →
  no `<img>`, no `plate__zoom`, resting note instead. The rail must still render: a resting
  work is still a work you can keep, which is the rule `daily/_day.html.erb:78-80` already
  states. So the rail is **unconditional** in `_painting.html.erb` — unlike `_day`'s, it
  has no preview mode and no zoom child, so there is no state in which it is empty.
- **A reader with a very large collection.** `where(painting: @paintings)` is bounded by
  the page's ten ids regardless of collection size. The `pluck` returns at most ten rows.
  No unbounded read anywhere in this story.

## Tests (R1 — written with the code, not after)

System (`test/system/feed_test.rb`, `test/system/favorites_test.rb`):
1. **Regression guard for nested frames** (downgraded from a gate by `/plan-eng-review` —
   see above; Turbo's own source settles the behaviour, this catches a future Turbo bump).
   Keep a work on `/feed` → the mark fills, the URL does not change, and a work further
   down the page is still present, i.e. the outer frame did not navigate.
2. Keep on `/artists/:slug` → mark fills, no navigation, heading still on screen.
3. Unkeep from `/feed` → mark empties, still no navigation.

Integration (`test/integration/favorites_test.rb`, `feed_test`-adjacent):
4. `/feed` renders one `keep_<id>` frame per work **with no `src` attribute** — the
   forcing function for story success signal 2. A regression to fetching frames fails here.
5. Query count on `GET /feed` grows by exactly **one** versus today (assert on
   `ActiveSupport::Notifications` sql counts), not by 2N. **Pins the two-`COUNT(*)` fix
   too** — the baseline it measures against is the corrected one.
6. A keep POST originating from a compact surface renders **no** `.rail__count`; the same
   POST from `/` still renders it. Both branches of `compact`, or the local lands in one
   and misses the other.
7. `GET /feed` answers `private` and never `public` — and **carries an ETag**, which is the
   assertion that pins the A1 finding: the middleware, not this controller, is what makes
   the page's per-reader body safe to revalidate.
8. **REGRESSION — mandatory, not optional.** `/artists/:slug`: GET, keep a work, GET again
   with the first `ETag` → **200 with the filled mark**, never a 304 with the outline one.
   This story deletes `stale?` from a shipped controller, so this is the test that proves
   `Rack::ETag`'s body digest actually replaces it. If the reading of the middleware in the
   freshness section is wrong, this is what fails.
9. `/` is unchanged: still a frame **with** `src`, still no `Set-Cookie`, still
   `public` — `public_cache_headers_test.rb` must stay green untouched.

Design / accessibility (`test/system/design_test.rb`, `dynamic_type_test.rb`):
10. The feed's keep control meets the 44px touch-target bar (DESIGN.md rule 9).
11. `dynamic_type_test.rb` at 375×667 on `/feed`: assert the plate is smaller but not
    cropped, at the accessibility text cap. This test already rejected a `22rem` guess
    once (`application.css:569`); it is the instrument for the CSS change, so extend it to
    `/feed` rather than trusting the arithmetic in this file.

## Implementation tasks

1. `ApplicationController`: `kept_ids_for(paintings)`, private, next to `reader_favorites`
   (CQ1 — one copy, not two).
2. `favorites/_control.html.erb`: add `compact:` (default false); suppress the count link;
   add the `params: { compact: "1" }` hidden field when compact. **Rewrite the header
   comment** — it documents only the fetched-frame architecture and opens "The keep
   control's per-visitor half", and this partial now serves two architectures (CQ2).
3. `favorites_controller.rb`: thread `compact:` through `render_control` from
   `params[:compact]`. **Update the ASCII diagram at `:12-18`** — it draws
   `GET /` → `GET /collection/42/control` as *the* flow, and after this story that is one
   of two (A3). A stale diagram misleads worse than no diagram.
4. `paintings/_painting.html.erb`: render `.rail` after the plate, holding
   `favorites/control` inline — `kept: kept_ids.include?(painting.id)`,
   `autofocus: false`, `compact: true`. No zoom glyph (story non-goal).
   **`count:` is not passed at all on the compact path** — an earlier draft passed
   `count: 0`, which is a falsehood sitting in a local: a reader with 12 kept works would
   have `0` in scope, and the day the `compact` guard is removed or inverted the count
   renders as zero with nothing failing. Make the partial read `count` only inside the
   `compact == false` branch (`local_assigns[:count]`), so a missing count is a missing
   local rather than a wrong number. Found by `/plan-design-review`.
5. `paintings_controller.rb`: `@kept_ids = kept_ids_for(@paintings)`. **No `no_store`** —
   A1. Also collapse the double `Painting.count` at `:8-9` into one.
6. `artists_controller.rb`: `@kept_ids = kept_ids_for(@paintings)`, and **delete `stale?`
   and its `count, latest` aggregate** (A1). `private_revalidate` stays. No fingerprint.
7. `paintings/_page.html.erb` and `artists/show.html.erb`: pass `kept_ids` into the
   collection render.
8. CSS: reserve rule to `.plate:has(+ .rail) .plate__img`; rewrite the now-false comment
   at `:578-582`.
9. **DESIGN.md: all four amendments above, in this commit** — plus the narrowing line in
   `decisions/0010` that D1 owes. Not a follow-up: R1 says no artifact without its
   enforcement in the same unit of work, and DESIGN.md is the enforcement for a visual
   idiom. A `.rail` that means two different things on two sets of screens, undocumented,
   is how the next reader "fixes" it back.
10. Remaining tests 4–11 (T4–T6 below add their own).
11. `bin/ci` green → `/qa` → `/simplify` → `/code-review` → re-verify → ship + `SHIPLOG.md`.

### Added by design review (2026-08-19)

Each derives from a finding above; none is padding.

- [ ] **T1 (P1, human: ~20min / CC: ~3min)** — `DESIGN.md` — narrow the four statements this
  story contradicts
  - Surfaced by: Pass 5 — plan proposed zero DESIGN.md edits while contradicting `.rail`
    ("Zoom, then Keep, then the count"), "The frame ships default content", the −44px screen
    list, and "The count keeps its word"
  - Files: `DESIGN.md`
  - Verify: read back — each of the four now names which screens it governs
- [ ] **T2 (P1, human: ~10min / CC: ~2min)** — `decisions/0010` — record that the count
  mitigation is scoped to `/`
  - Surfaced by: D1 — mark-only deletes one of two mitigations a direction-level decision
    bought a documented 34%-icon-comprehension risk with (R4)
  - Files: `decisions/0010-actions-become-a-rail.md`
  - Verify: the amendment states the tripwire — a misread glyph in the five `BET.md`
    conversations falsifies this line, and labels are the costed fix
- [ ] **T3 (P1, human: ~15min / CC: ~3min)** — `favorites/_control.html.erb` — read `count`
  only on the non-compact path
  - Surfaced by: Pass 5 — plan passed `count: 0` on the compact path, a falsehood that
    renders as a real zero the day the `compact` guard is removed or inverted
  - Files: `app/views/favorites/_control.html.erb`, `app/views/paintings/_painting.html.erb`
  - Verify: test 6 — a compact write renders no `.rail__count`; a `/` write still does
- [ ] **T4 (P2, human: ~45min / CC: ~10min)** — `test/system/dynamic_type_test.rb` — extend
  the fold assertions to `/feed` at 375×667
  - Surfaced by: Pass 6 — the −44px is asserted for `/` only; this story applies the same
    reserve to two more screens, and DESIGN.md:325 records this test rejecting a `22rem`
    guess once already
  - Files: `test/system/dynamic_type_test.rb`
  - Verify: `bin/rails test test/system/dynamic_type_test.rb` — plate smaller, never cropped,
    at the accessibility cap
- [ ] **T5 (P2, human: ~30min / CC: ~8min)** — `test/system/feed_test.rb` — assert the
  identity-died-mid-scroll state renders in place
  - Surfaced by: Pass 2 — the error state is real, already built
    (`application_controller.rb:95-102`), and asserted nowhere on a multi-frame page
  - Files: `test/system/feed_test.rb`
  - Verify: revoke the device mid-page, submit a keep, assert a `Sign in` caps-link replaces
    that one mark and no other post changes
- [ ] **T6 (P3, human: ~20min / CC: ~5min)** — `test/system/feed_test.rb` — assert tab order
  is plate-zoom → keep → artist-link per post
  - Surfaced by: Pass 6 — stops per feed page go 20 → 30; accepted, but nothing holds the
    order if the rail ever moves relative to the label
  - Files: `test/system/feed_test.rb`
  - Verify: walk the first two posts by keyboard, assert the sequence

### Added by eng review (2026-08-19)

- [ ] **T7 (P1, human: ~1h / CC: ~12min)** — freshness — delete `stale?` from
  `ArtistsController`, add no `no_store` anywhere
  - Surfaced by: Architecture A1 — `rack/etag.rb` `skip_caching?` only skips on an existing
    ETag/Last-Modified, so both surfaces already get a per-reader-correct body digest;
    `Rack::ConditionalGet` + `Rack::ETag` confirmed in the middleware stack
  - Files: `app/controllers/artists_controller.rb`, `app/controllers/paintings_controller.rb`
  - Verify: test 8 (regression) — keep on an artist page, re-request with the prior ETag,
    expect 200 with the filled mark; and test 7 — `/feed` carries an ETag and is `private`
- [ ] **T8 (P1, human: ~20min / CC: ~4min)** — `ApplicationController` — one
  `kept_ids_for(paintings)`, not two copies
  - Surfaced by: Code Quality CQ1 — `application_controller.rb:135-139` already argued this
    case verbatim when `/you` became the second caller of `reader_favorites`
  - Files: `app/controllers/application_controller.rb`, both walled controllers
  - Verify: `grep -c "reader_favorites.where(painting" app/controllers` returns 1
- [ ] **T9 (P2, human: ~30min / CC: ~6min)** — comments and diagrams — update the two that
  this story falsifies
  - Surfaced by: Architecture A3 + Code Quality CQ2 — `favorites_controller.rb:12-18` draws
    the fetched-frame flow as *the* flow; `_control.html.erb`'s header opens "The keep
    control's per-visitor half". Both describe one of two architectures after this story
  - Files: `app/controllers/favorites_controller.rb`, `app/views/favorites/_control.html.erb`
  - Verify: read both back — each names which surfaces it governs
- [ ] **T10 (P2, human: ~5min / CC: ~1min)** — `PaintingsController#index` — one
  `Painting.count`, not two
  - Surfaced by: Performance P1 — `paintings_controller.rb:8-9` issues two identical
    `COUNT(*)` per request, on every feed load including all eleven lazy page fetches.
    Pre-existing, in a file this story edits, solo repo
  - Files: `app/controllers/paintings_controller.rb`
  - Verify: test 5 — the query-count assertion measures against the corrected baseline
- [ ] **T11 (P3, human: ~10min / CC: ~2min)** — `kept_ids` is a required local
  - Surfaced by: Code Quality CQ3 — copying `local_assigns.fetch(:show_artist, true)` here
    would render every mark un-kept when a caller forgets the local; a wrong mark is worse
    than a raised error
  - Files: `app/views/paintings/_painting.html.erb`
  - Verify: render the partial without `kept_ids` in a test, expect it to raise

## What already exists — reuse, do not reinvent

- `favorites/_control.html.erb` — the frame, the button, the toggle, the aria contract.
  One new local; do not write a second control partial.
- `favorites/_keep_glyph.html.erb` — the mark, filled and outline.
- `reader_favorites` / `identified?` (`application_controller.rb:151-161`) — the identity
  question, answered once for the whole app.
- `no_store` / `private_revalidate` (`application_controller.rb:168, 214`) — do not
  hand-roll headers.
- `.rail`, `.rail__slot`, `.rail__act`, `.rail__form` (`application.css:1069-1115`) — the
  whole visual treatment, unchanged.
- `FavoritesController#create/#destroy` — the write paths, including the double-tap and
  orphan-row branches. This story adds no write path.

## Worktree parallelization strategy

Added by `/plan-eng-review`. Three lanes, two genuinely parallel.

| Step | Modules touched | Depends on |
|---|---|---|
| Ruby + views | `app/controllers/`, `app/views/` | — |
| Docs | `DESIGN.md`, `decisions/` | — |
| CSS | `app/assets/stylesheets/` | — |
| Tests | `test/` | Ruby + views |

```
Lane A  Ruby + views ──────────────> Tests        (sequential, shared app/ then test/)
Lane B  Docs                                       (independent — DESIGN.md, decisions/0010)
Lane C  CSS                                        (independent — one selector + one comment)
```

Launch A, B and C in parallel worktrees; merge B and C whenever they land. Tests wait on A
and stay in Lane A rather than becoming a fourth — every test in this plan asserts against
code Lane A writes, so splitting them buys nothing and costs a merge.

**No conflict flags.** The three lanes share no module directory. The only coupling is
semantic, not textual: Lane B's DESIGN.md amendment 3 describes the reserve rule Lane C
writes, so if Lane C's arithmetic changes under review, Lane B's text needs the same edit.

Honest caveat: this is a 15-file, mostly one-line-per-file change on an Express lane. The
parallelization is available, not obviously worth the worktree overhead. Sequential is
fine and probably faster end to end.

## Known gaps, named rather than omitted

- **Evidence is a design review, not a user.** Said in `story.md` Intake and repeated here
  so it survives into the kill-review read. The structural argument (baseline item 4
  half-wired) is what carries this, not a gallery observation.
- **Nothing measures whether keeps originate off `/`.** Session gate 6 is unmet. The
  tests hold the mechanism; no instrument holds the outcome.
- **The `/` architecture stays split from the walled one.** Two rendering modes for one
  control is a real cost, paid because `/`'s public-cache line is load-bearing and the
  walled surfaces' is not. If `/` ever goes private, the two collapse into one and the
  `src` branch should be deleted, not kept.

## Open questions for review

1. ~~**Design:** accept the 44px plate reserve at 375×667?~~ **CLOSED by
   `/plan-design-review` 2026-08-19 — it was never open.** Rule 2 already reads
   *"`--rail-reserve` is `0` everywhere except the screens carrying an action rail"*
   (DESIGN.md:364-369), which is general, and `decisions/0010:39-43` measured and accepted
   the identical −44px on the identical device for `/`. Extending the rail to a screen is
   *how the existing rule is meant to work*, not a new trade. What was actually owed was
   the documentation update, now task 9. The overlay alternative stays refused by rule 5
   (*nothing hovers over an artwork*) and by `decisions/0010:73-74`.
2. ~~**Design:** mark-only vs the count word?~~ **CLOSED — D1 above, 2026-08-19.**
   Mark-only, with the debt written into DESIGN.md amendment 4 and a narrowing line in
   `decisions/0010`. Reframed on the way to the answer: it was never a taste call about
   noise, it was whether to delete one of the two mitigations `decisions/0010:98-104` bought
   the label-less rail with.
3. ~~**Eng:** artist-page ETag fingerprint scoped to the whole collection vs this artist's
   ids?~~ **CLOSED — `/plan-eng-review` A1, 2026-08-19. The question dissolved.** There is
   no fingerprint: `Rack::ETag` digests the response body, which already contains the kept
   marks, so no hand-rolled reader key is needed at any scope. `stale?` is deleted.
4. ~~**Eng:** `no_store` on `/feed`, or a conditional GET there too?~~ **CLOSED — same
   finding, and the premise was false.** The question rested on "the feed has no ETag
   today, so nothing is being given up." It has one — a body digest from the middleware —
   so `no_store` would have discarded working 304s and bfcache to solve a problem that did
   not exist. `/feed` gets zero freshness lines.

## Deviations (added during build)

- _(none yet)_

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | UNAVAILABLE | usage limit hit, no output |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 7 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR (FULL) | score: 5/10 → 9/10, 2 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

Design pass scores: Info Arch 6→9, States 4→9, Journey 5→9, AI Slop 10 (no findings),
Design System 4→9, Responsive/A11y 5→9. Tasks T1–T6.

Eng review: Architecture 3, Code Quality 3, Performance 1, test gaps 16 (nothing built
yet), 1 regression test made mandatory. Scope challenge triggered at 15 files and produced
one reduction. Tasks T7–T11.

**The load-bearing finding (A1).** Two successive drafts of the freshness section were
wrong in opposite directions — one added a reader fingerprint to the artist page's ETag,
one replaced both surfaces with `no_store`. Reading `rack-3.2.6/lib/rack/etag.rb` settled
it: `skip_caching?` skips only on an existing ETag or `Last-Modified`, so both walled pages
already receive a body-digest ETag that is inherently per-reader-correct. Net: `stale?`
deleted from `ArtistsController`, no `no_store` anywhere, zero freshness lines on `/feed`.
Held by mandatory regression test 8.

Two other claims were settled by reading source rather than asserting: the nested-frame
risk (`turbo-rails 2.0.23` — a frame intercepts only forms whose *closest* frame it is, so
`feed-page-N`'s `target="_top"` never applies), and the query plan (EXPLAIN QUERY PLAN
against a replica schema — **covering index in both identity worlds**, including the
partial `user_id` one).

Visual mockups deliberately not generated: the component's geometry is fixed to the pixel
in DESIGN.md:269-272 and `application.css:1069-1115`, and the only visual question is
dimensional (−44px at 375×667) — `dynamic_type_test.rb` is the instrument, and DESIGN.md:325
records it rejecting a `22rem` guess once already.

**CROSS-MODEL:** none available. Codex was `ready` at preflight and hit its usage limit
mid-run, returning no output. The Claude-subagent fallback was not dispatched — this
session carries a standing instruction not to call the Agent tool unasked. Re-runnable.

**VERDICT:** DESIGN + ENG CLEARED — ready to implement. The coverage fill shipped as
`specs/0019-the-coverage-fill`, so the WIP slot is free and nothing blocks this.

**UNRESOLVED DECISIONS:**
- Outside voice never ran (Codex usage limit). Not a blocker — it never gates shipping —
  but no independent model has challenged this plan, and the A1 correction shows the plan
  was wrong twice on the same section before source-reading caught it.
