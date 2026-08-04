# 0006 — Implementation plan
Status: **Design-reviewed** (`/plan-design-review` 2026-08-04 — 9 decisions, 6/10 → 9/10,
variant B approved) and **Eng-reviewed** (`/plan-eng-review` 2026-08-04 — 8 findings,
scope reduced, outside voice absorbed).

**Depends on story 0007** (`specs/0007-no-session-cookie-on-public-pages/`), which ships
first. Everything below assumes public pages no longer emit `Set-Cookie`.

## Approach

Three surfaces, one new table, and one pre-existing header defect that this feature is the
first to actually stand on.

- **The control** — a keep/unkeep toggle at the foot of the label on `/` and `/days/:date`.
- **The collection** — `GET /collection`, a list reusing the `.days` row wholesale.
- **The identity** — an anonymous, permanent, signed cookie. No account, no email.

Everything hard about this story is in one sentence: **the pages that need a per-visitor
control are the two pages we deliberately made publicly cacheable.**

---

## The load-bearing constraint: public pages must stay impersonal

`/` and `/days` are `public, no-cache` + ETag (stories 0001 and 0003). Rendering a kept/
unkept state into that HTML means one of two bad outcomes: drop `public` and lose shared
caching on the product's two most-hit pages, or keep it and let a shared cache serve one
reader's collection state to another.

**The rule this plan holds to: the public HTML is byte-identical for every visitor, and
public responses carry no `Set-Cookie`.** All per-visitor state lives behind one private
fragment request.

```
GET /                                    GET /collection/42/control
  public, no-cache, ETag                   private, no-store, Vary: Cookie
  identical for everyone                   this reader's state only
  no Set-Cookie                            may Set-Cookie
  |                                        |
  <turbo-frame id="keep_42"                <turbo-frame id="keep_42">
      src="/collection/42/control"           form → Keep this  |  ✦ Kept
      loading="lazy"></turbo-frame>          Your collection (7) →
                                           </turbo-frame>
```

Toggling posts from inside the frame and re-renders the frame. The day page never reloads,
never navigates, and never learns who is reading it.

### The prerequisite, split out at eng review

This plan originally carried the fix for a pre-existing defect: **every public page already
sets a session cookie**, because `csrf_meta_tags` writes `session[:_csrf_token]`. Measured
on this checkout, `/` and `/days` return `public, no-cache` **and**
`Set-Cookie: _taste_maker_session=…`. A shared cache storing that response replays one
visitor's session together with the matching masked CSRF token from the same body.

Not theoretical: `Dockerfile:77` starts production with `bin/thrust`, and Thruster 0.1.23
ships a 64MB HTTP cache enabled by default with no config file. The defect goes live at the
first deploy whether or not favorites ever exists.

**Now `specs/0007-no-session-cookie-on-public-pages/`, which ships first.** Same reasoning
story 0003 applied to the linen 404: an app-wide change belongs in its own revertable
commit, and this one is a security fix that should not wait behind a two-day feature with
the store deadline on Aug 14. Story 0007 also absorbed three findings from this review — the
layout belongs on `Admin::BaseController`, the curator's preview needs an explicit
`layout: "application"`, and the admin-delete test must assert the meta tag rather than
issue an integration `DELETE`.

**What 0006 keeps:** one guard test that adding the keep frame does not put a `Set-Cookie`
back onto `/`.

---

## Identity: anonymous, device-local, server-stored

**Decision: a random token in a permanent signed cookie. Favorites rows live server-side,
keyed by that token. No account, no email, no password, no PII.**

`CLAUDE.md` says this is a spec decision with evidence, not an assumption. The evidence:

| Option | Why not / why |
|---|---|
| **Rails 8 auth generator (accounts)** | Costs the Action Mailer stack `config/application.rb:11` deliberately leaves commented out, SMTP and deliverability, password reset, and an App Store privacy label reading *Contact Info → Email, linked to you*. Puts a signup wall in front of persona 1's calm — the bar `CLAUDE.md` names as one of two moats. BET.md wants the app live **Aug 14**, with the iOS shell, APNs and first deploy all still unbuilt. |
| **Pure client-side (`localStorage`)** | Kept state would render after JS, so the day page flashes the wrong state on the surface whose quality bars are *calm* and *fast*. The collection page would need a client fetch to render anything. And WKWebView evicts `localStorage` under storage pressure the same way it evicts cookies — no durability win for the loss. |
| **Anonymous token, server-stored** ✅ | One tap, no wall, no PII. State renders server-side, so no flash. Same durability as `localStorage` in the shell, and the list itself is on our disk, which is what makes a future claim path possible without building it now. |

**The risk, stated plainly and not solved here: delete the app and the collection is gone.**
That is exactly persona 2's fear, and this plan does not fix it. What it does is refuse to
build accounts speculatively for a collection that on ship day holds one work. **Trigger,
written down rather than built:** the first time a real user asks for their collection on a
second device, or the first time accounts arrive for any other reason, favorites gain a
nullable `user_id` and a claim path. A nullable column added later is a migration; an auth
system added now is infrastructure for later.

### The cookie

Three private methods on `FavoritesController` — **not a concern**. A concern with exactly
one includer is a file boundary standing in for a code boundary, and the rule these methods
enforce is "only this controller may touch the cookie", which a private section states more
directly than a shared module. Extract it when a second caller actually exists.

```ruby
# app/controllers/favorites_controller.rb  (private section)

COOKIE = :collector

# The reader's identity is established when the control fragment is READ, not
# when they first keep something. That endpoint is private + no-store, so a
# Set-Cookie there is safe — and it means every write already carries an id.
#
# Minting on the first write instead looked cheaper and had a hole: two tabs,
# a brand-new reader, neither holding a cookie, both tapped. Each request mints
# a different id, each writes a row, the browser keeps whichever Set-Cookie
# lands last, and one row is orphaned under an id nobody holds. The unique
# index does not catch it — it is scoped to the token, and the tokens differ.
# Both tabs would say "Kept" and one work would never appear.
def collector_token
  cookies.signed[COOKIE].presence || mint_collector_token
end

def mint_collector_token
  SecureRandom.base58(24).tap do |token|
    cookies.permanent.signed[COOKIE] = {
      value: token, httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end
end

# What goes in the database. The cookie carries the raw token; the table stores
# only its digest, so a backup or a dump is not a set of working credentials for
# other people's collections. Every lookup starts from the cookie anyway, so
# hashing at the boundary costs one call and changes nothing else.
def collector_digest
  Digest::SHA256.hexdigest(collector_token)
end
```

**No public controller calls any of these.** `DailyController` and `DaysController` never
reference the cookie; the day page's contribution is a static `turbo_frame_tag` that is the
same bytes for everyone.

- **Separate from the session cookie**, not stored inside it: the session cookie expires
  when the browser closes, and a collection that evaporates on quit is worse than none.
- `httponly` — no script needs it, so no script gets it.
- Signed, 24 random base58 characters, digested before storage.
- **The reader is not anonymous after scrolling.** Loading the control fragment issues the
  cookie, so anyone who scrolls past the credit line on a day page has one. The **server
  still stores nothing** until they keep something — no `Favorite` row, no log line keyed to
  the token. This is the accepted cost of closing the two-tab race, and the plan says it
  plainly rather than claiming reading is anonymous.
- **Privacy labels (session gate 6): not asserted here.** The inputs are: a first-party
  functional cookie holding a random token, issued to every reader of a day page; server-side
  rows keyed to its digest; no email, no PII, no cross-app or cross-site tracking, and no
  analytics keyed to the token. Whether Apple's *Identifiers* or *Product Interaction*
  categories apply to that is a determination for **gate 6 before first external user**, not
  a claim this plan gets to make. What this plan does commit to, as the enforcement (R1):
  **no analytics is ever keyed to this token.** If that changes, the label determination is
  redone first.

---

## Data model

```ruby
create_table :favorites do |t|
  t.string     :collector_digest, null: false   # SHA256 of the cookie's token, never the token
  t.references :painting, null: false, foreign_key: true
  t.timestamps
end
add_index :favorites, %i[collector_digest painting_id], unique: true
```

**Keyed to the painting, not the daily pick.** `index_daily_picks_on_painting_id` is unique,
so today the two identify the same thing — but a pick can be rescheduled or deleted by the
curator, and a pick-keyed favorite would be destroyed by the foreign key when that happens.
An editorial action silently deleting something a reader kept is persona 2's nightmare in
miniature. Painting-keyed favorites survive it; the collection row simply stops linking
anywhere (see failure modes).

**The painting FK, stated as an invariant rather than left implicit.** `favorites` has
`foreign_key: true` to `paintings` with no `on_delete`, so SQLite *restricts*: a painting
somebody kept cannot be deleted. That is safe because **nothing deletes paintings** —
`db/seeds.rb` upserts by `mia_id` and only ever inserts or updates. If a future cleanup task
wants to remove works from the pool, it inherits this constraint and must decide what
happens to the collections holding them. Written down so that decision is made on purpose.

**Digest, not the raw token** (outside voice). The cookie is a bearer credential; a copy of
it in the database means a backup or a dump is a set of working credentials. Hashing at the
lookup boundary costs one call, changes no query, and is the one column here that is
genuinely expensive to change after launch — migrating raw-to-digest later invalidates every
cookie and orphans every collection. Cost accepted: a token seen in a cookie can no longer
be matched to its rows, so per-reader debugging is impossible by design.

The unique index is both the correctness rule and the lookup index. **No
`[collector_digest, created_at]` index yet** — the composite already covers lookup by
digest, and sorting a handful of rows in SQLite is free. **Trigger:** any single collection
passing 500 rows.

```ruby
class Favorite < ApplicationRecord
  belongs_to :painting

  validates :collector_digest, presence: true
  validates :painting_id, uniqueness: { scope: :collector_digest }

  scope :collected_by, ->(digest) { where(collector_digest: digest) }
end
```

Not `scope :for` — `for` is a Ruby keyword and reads like a bug at every call site.

---

## Routes

```ruby
# One reader's own collection, and the only per-visitor fragment in the product.
get    "collection" => "favorites#index", as: :collection
get    "collection/:painting_id/control" => "favorites#control", as: :favorite_control
post   "collection/:painting_id" => "favorites#create"
delete "collection/:painting_id" => "favorites#destroy", as: :favorite
```

`favorite_path(painting)` serves both the POST and the DELETE. Constrained to
`painting_id: /\d+/`.

**`#create` accepts any painting in the pool, deliberately.** All 110 are already public at
`/feed`; what is embargoed is which painting runs on which *day*, and keeping a painting
reveals nothing about the queue. Restricting to published paintings would buy no privacy and
would strand the orphan case below.

---

## Controllers

```
                    GET /                        GET /collection/42/control        POST/DELETE /collection/42
                       |                                    |                                  |
              DailyController#show                 FavoritesController#control        FavoritesController#{create,destroy}
                       |                                    |                                  |
              renders <turbo-frame src>            cookie present? ── no ──> MINT             cookie is already there
              same bytes for everyone                        |                                  |
              public, no-cache, ETag               digest = SHA256(token)             find_or_create_by / destroy_by
              NEVER touches the cookie                       |                                  |
                                                   private, no-store, Vary: Cookie     render _control, autofocus: true
                                                   render _control, autofocus: false
```

- `#control`, `#create`, `#destroy` all render the same `favorites/_control` partial, so
  there is one description of the two states. **The partial contains the
  `turbo_frame_tag`**, not just its contents — a frame-targeted response has to carry a
  matching frame id or Turbo reports missing content.
- `autofocus` is a local, **true only on the write responses** (D3). On the `control` GET it
  is false, so the lazy frame landing mid-scroll never steals focus.
- Every one of them sets `Cache-Control: private, no-store` and `Vary: Cookie`.
- `#index` is also `private, no-store` — it is the reader's own page and has no shared-cache
  story.
- **`#control` is where the cookie is minted.** Every other action finds it already set,
  because Turbo always issues this GET before any tap is possible.
- `#create` still calls the minting reader as a **fallback** — a scripted POST that skipped
  the frame must still work. In practice the two-tab cold-start race is gone, because both
  tabs load the fragment before either can be tapped.
- `#create` uses `find_or_create_by` and rescues `ActiveRecord::RecordNotUnique` as success;
  two taps that race are one kept work, not a 500.
- `#destroy` uses `destroy_by` and is idempotent: unkeeping something already gone renders
  the unkept state rather than 404ing.

---

## The control, specified

Approved direction: **variant B, "the wall label's last row"** (see Approved Mockups). The
control lives *inside* `.label`, after `label__credit`, left-aligned with the rest of the
label. It belongs to the artwork, not to the end of the page — which is why the coda stays
the single ending. Not floating on the artwork (`DESIGN.md` rule 5), not in the masthead,
not sticky.

Rejected at review, with the reason each failed:

| Variant | Why not |
|---|---|
| **A — its own centred block** above the coda | Two closing beats. The unkept control in `--ink-dim` read as a caption under the credit, and on a past day the foot stacked five near-identical small-caps rows. |
| **C — folded into the coda's link row** | Asks for commitment after "See you tomorrow." **Measured: 3 items wrap to 3 lines at 375**, so the one-ending idea collapses into the exact stack it was avoiding, further from the artwork. |

```
  …note…
  The John R. Van Derlip Fund · 54.15                    ← .label__credit

  ┌ turbo-frame#keep_42 ────────────────────────────────┐
  │  KEEP THIS                                           │  ← unkept
  └──────────────────────────────────────────────────────┘
                        ✦
                 See you tomorrow.                          ← .coda, unchanged
                 WANDER THE FULL GALLERY →
```

kept state — **left-grouped, not spread** (D8):

```
  ┌ turbo-frame#keep_42 ────────────────────────────────┐
  │  KEPT · REMOVE   7 KEPT →                            │
  └──────────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Row | `.keep` — `display: flex; align-items: center; justify-content: flex-start; gap: 1.6rem; margin-top: 2.2rem`. **`flex-start`, never `space-between`**: at 1280 the measure is 680px and spreading put two related items 466px apart, which reads as the `.walk` nav row rather than as a pair (D8). |
| Gap above | `2.2rem`, deliberately **more than the credit's own `1.3rem` top margin**. Equal spacing would group the row with the credit block; more air makes it the label's action row. One number, and it is the whole grouping signal. |
| Toggle | `<button>` inside `form_with`, `.caps-link .keep__toggle`, `aria-pressed`. Unkept `Keep this`, kept `Kept · Remove`. **Both `--gold`** — gold is the product's link colour and this is the one thing on the page that acts. Hover `--gold-deep`. |
| No glyph | **No `✦`, no heart, no star, no icon font** (D7). `✦` is the product's *only* ornament (`DESIGN.md` rule 6) and using it as a state marker put two `✦` glyphs 40px apart meaning different things. The state delta is carried by words: one label, then two words and the middle dot `.label__credit` already uses. |
| Accessible name | Unkept: "Keep this work in your collection". Kept: "Remove this work from your collection". The visible label carries state **and** next action, so it needs no second phrasing job. |
| Collection link | `.caps-link .keep__link`, **`7 kept →`** — count first, no parentheses (D6), matching the masthead's existing `pluralize(@picks.size, "day")` → "14 days". Rendered **only when the count is > 0**; the countless door on `/days` covers discovery at zero. |
| Touch target | `min-height: 2.75rem` (44px) on the toggle *and* the link. `.caps-link` carries no min-height of its own — `.walk__step` adds it, per ISSUE-002 (commit 866bbc2) where walk links shipped as 15px targets. |
| Frame placeholder | Empty, `min-height: 2.75rem`, no spinner, no fade. Space reserved so nothing shifts when the frame lands. |
| Never | No card, no fill, no border box, no radius, no shadow, no toast, no confirmation, no count animation. Rules 5, 6, 7. |

**Chrome modes (D2).** The frame renders for `:front_door` and `:archive` only. **Not
`:preview`.** A curator checking a queued day must see the reader's page; a live keep
button there also lets curator keeps write real rows against unpublished works and pollute
the only usage signal this feature will have. `_day.html.erb` already branches on `chrome:`
three times — this is a fourth condition on an existing branch, not a new concept. Story
0003 made exactly this mistake with the archive link and fixed it the same way.

`loading="lazy"` on the frame: the control sits below a 55vh plate plus the note, so on a
phone it is under the fold. A reader who bounces at the picture costs zero extra requests.

**Non-JS degradation.** Turbo frames need Turbo. Without it the frame renders empty and the
reader sees nothing where the control would be — no dead button, no error. The product
already depends on Stimulus for zoom and the `More` toggle; noted so it is a known state
rather than a discovery.

---

## The collection page

Reuses `.days` **wholesale** — same row, same thumbnail geometry, same no-clamp rule, same
`<ol>`/`<li>`. It is the same object (a list of works with dates and a recognition mark),
so it gets the same component, not a second one.

Differences from `/days`, all of them content:

| | `/days` | `/collection` |
|---|---|---|
| Order | `scheduled_on` desc | `favorites.created_at` desc — **their** order, not ours |
| Grouping | month headings | none; "the month I kept it" is not a fact anybody wants |
| Masthead aside | `pluralize(n, "day")` → "14 days" | `pluralize(n, "work")` → "7 works". Same idiom, same slot; the count-first "7 kept" phrasing belongs to the *link*, not to a page's own header |
| Row link | the day | the day, via `day_link_path`; **absent** when the pick is gone |
| Coda | `Today →` | see below |
| Thumbnails | `artwork_src(painting, size: 240)` | identical — ISSUE-001 (commit 2da2f7a) shipped full-size originals into a thumbnail once already |

### The two doors (D1)

The plan originally gave the collection exactly one entrance: the lazy frame at the bottom
of a day page. For persona 1 that is a side room off the ritual; for **persona 2 it is
backwards**, because the collection *is* the product and the daily artwork is how it gets
built. A reader with seven kept works had to open today's artwork, scroll past the plate
and the whole note, and wait for a fragment, to reach the room they came for.

Fix, costing one line of ERB each way:

- **`/days` coda gains `Your collection →`** — *countless*, so it is byte-identical for
  every visitor and drops straight into the public cached page. No frame, no endpoint, no
  cache change. This is the one place the "no door onto an empty room" rule is deliberately
  broken: at zero the door is how the feature gets discovered at all, and the empty state
  below is written to earn the visit.
- **`/collection` coda gains `The days behind you →`** beside `Today →`. The two list pages
  become siblings and both pass the trunk test.

### Coda copy

```
                         ✦
   To let one go, open it and unkeep it.        ← .coda__line
   Kept on this device — free, and yours.       ← .coda__note  (D4)
   THE DAYS BEHIND YOU →      TODAY →
```

**The device line is not decoration (D4).** Kept works live in a cookie-keyed record on one
device; delete the app and the collection is gone. The failure-modes table names that risk
to the developer and the reader is told nothing — which is how somebody reinstalls, finds an
empty collection, and concludes the app took it. That reads identically to the paywall
betrayal in persona 6's reviews. One honest sentence turns a future betrayal into a stated
limit, and it frames a later accounts feature as a gain rather than an apology. `.coda__note`
treatment (`--ink-faint`, 0.95rem), never `--warn`: this is a fact, not an error.

### Empty state (D5)

Now a real first impression, not an unreachable edge — the countless door on `/days` sends
first-time readers here. `.page--empty` + ornament, then all three jobs an empty state has:

```
                         ✦
   The works you keep will gather here.         ← promise, mirrors "The days will collect here."
   Keep this sits under every artwork.          ← context: the one thing to learn
   TODAY →                                      ← the action
```

"Nothing kept yet." was cut: it reports an absence, teaches nothing, and would be the only
line a curious first-time visitor ever reads about this feature.

### The row partial (eng review)

"Reuses `.days` wholesale" had nothing to reuse: the row is 19 lines of inline ERB inside a
loop at `app/views/days/index.html.erb:23-41`, and those lines carry the accessibility
contract (one link per row, a spoken name of date + title + artist, a real `<time datetime>`,
`alt=""`, lazy past the fourth row) plus the ISSUE-001 240px thumbnail fix. Copying them
means two homes for both.

**Extract `days/_row.html.erb` first, as its own commit, with the archive's existing tests
proving behaviour is unchanged.** Then both list pages render it. Make the change easy, then
make the easy change. Locals: `pick:`, `painting:`, `current:`, `eager:`, `linked:` — the
last one is what the orphan row turns off.

### `#index`, exactly

Five fixed queries, no N+1, no per-row lookup in the template:

```ruby
favorites = Favorite.collected_by(collector_digest)
                    .includes(painting: { image_attachment: :blob })
                    .order(created_at: :desc).to_a                    # their order, not ours

picks   = DailyPick.published.where(painting_id: favorites.map(&:painting_id))
                   .index_by(&:painting_id)                           # hash, NOT find-in-loop
@current = DailyPick.current                                          # eng review, issue 3

@rows = favorites.map { |f| [ f, picks[f.painting_id] ] }             # pick may be nil = orphan
```

- **`index_by`, not `find` inside the loop.** Otherwise the template grows an O(n²) scan
  that looks like reuse.
- **`@current` is loaded and passed to `day_link_path(pick, @current)`.** Without it every
  row takes the dated branch, so the row for the work on the front door 301s on every tap —
  the exact wart story 0003 removed. Gap days come free, because `DailyPick.current` already
  holds the previous pick over and the helper keys on the pick rather than the calendar.
- A `nil` pick is the orphan row: the work is kept, its day is gone, the row renders
  unlinked with its own `Remove`.

---

## Interaction states

| Surface | Loading | Empty | Error | Success |
|---|---|---|---|---|
| **Control frame** | Reserved 44px of space, nothing visible. No spinner — one small fragment does not earn ceremony. **Nothing is announced** and **focus does not move** when it lands (D3). | No cookie yet ⇒ the fragment **issues one** and renders the unkept state. The server stores nothing until a keep happens. | Frame request fails: the space stays empty; the page is unaffected and still reads, zooms and navigates. | `Keep this` ⇄ `Kept · Remove`, in place, no navigation. |
| **Toggle** | Button `disabled` while in flight (Turbo does this); no visual state change, so no flicker on a fast response. | — | POST fails: the frame re-renders from the server's actual state, so the button never lies about what is stored. | Frame replaced by the same partial in the other state, **with focus restored to the toggle** (D3). |
| **Preview** (`chrome: :preview`) | — | — | — | **No frame at all** (D2). The curator sees the reader's page. |
| **Collection** | One render. | Promise + context + `Today →` — see Empty state above. | A painting whose blob is unreadable falls back to the CDN via `artwork_src` — already handled. | Rows newest-kept first, ending in the coda. |
| **Orphaned row** (kept work whose day was deleted) | — | — | — | Renders **unlinked**: date omitted, title and artist in place, thumbnail as usual, plus a `Remove` button. The one row that is not a link is the one row that can carry a button without nesting interactives — and it is the only row whose owner has no other way to remove it. |
| **Entry links** | — | `Your collection →` on `/days` shows **always** (countless, cacheable). `7 kept →` in the frame shows **only above zero**. | — | Both point at `/collection`; `/collection` points back at `/days` and `/`. |

---

## Responsive

One row shape at every width. **No breakpoint** — the breakpoint the plan would otherwise
grow exists to fix a spread this row no longer has.

Measured on the approved variant with the final copy, real CSS, real work:

| | 375px | 1280px |
|---|---|---|
| `.keep` row width | 338px (`.page` padding is `5vw` a side) | 680px (`--measure`) |
| `Keep this` | 90 × 44 | 90 × 44 |
| `Kept · Remove` | 133 × 44 | 133 × 44 |
| `7 kept →` | 81 × 44 | 81 × 44 |
| Kept row content, left-grouped | 133 + 26 gap + 81 = **240px**, 98px slack | 240px, identical |
| Wrap | **none**, verified | none |
| Three-digit count (`128 kept →`) | ~+22px, still ~76px slack | fine |

The row is identical at both widths because `flex-start` makes it content-width. That is the
point of D8: the pair does not stretch, so there is nothing for a breakpoint to fix.

**Collection page:** inherits `.days` geometry unchanged — 112px thumbnail at ≥641, 72px at
≤640, fixed height and free width, no clamp on titles. The one addition is the orphan row's
`Remove`: it sits **below the artist line inside the text column**, which is 245px wide at
375 (338 − 72 thumb − 21 gap). A 44px-tall `.caps-link` reading `Remove` measures ~85px, so
it fits with room to spare and never competes with the thumbnail.

## Accessibility

- The toggle is a real `<button>` with `aria-pressed`, inside a real form. Not a link, not a
  div, not a checkbox styled as text.
- **No live region (D3).** The frame is `loading="lazy"`, so an `aria-live` on it would
  announce "Keep this work in your collection" the moment a screen-reader user scrolled past
  the credit — an announcement with no action behind it.
- **Focus is restored on every write (D3).** Turbo replaces the frame, which destroys the
  focused button and drops focus to `<body>` — a keyboard user would press Keep and be
  silently teleported to the top of the document. The `create` and `destroy` responses render
  the toggle with `autofocus`; the `control` GET does **not**, so the lazy frame never steals
  focus. Focus landing on the toggle is also what announces the new state, which is exactly
  what `aria-pressed` on a focused toggle is for.
- Visible label carries state and next action (`Kept · Remove`); the accessible name states
  the action plainly ("Remove this work from your collection").
- The middle dot is inside the button's text. The accessible name is set explicitly with
  `aria-label`, so no screen reader reads punctuation as content.
- 44px minimum target on the toggle, the collection link, and the orphan-row `Remove`.
  `.caps-link` has no `min-height` of its own — this is set on `.keep__toggle` /
  `.keep__link`, the same way `.walk__step` does it.
- Collection rows inherit `/days`' structure: `<ol>`/`<li>`, one link per row, full
  accessible name (date, title, artist), `<time datetime>`, `alt=""` thumbnails.
- Contrast from the token table: `--gold` 5.3:1, `--ink-faint` 5.1:1. No new colours.
- `:focus-visible` uses the existing global gold outline.
- No motion on this feature at all.

---

## The journey

| Step | User does | User feels | What supports it |
|---|---|---|---|
| 1 | Reads today's note, finishes it | absorbed | Nothing has changed about the page above this point |
| 2 | Sees `Keep this` under the credit | recognition — "oh, I can save this" | Gold, left-aligned with the label, 2.2rem of air above it so it reads as an action and not a second credit line |
| 3 | Taps | nothing dramatic, which is the point | No modal, no signup, no toast; the words change in place and focus stays put |
| 4 | Comes back next week, keeps another | accumulation | `7 kept →` climbs — the number is the reward |
| 5 | Opens the collection, from a day **or from the archive** | **ownership** — "this is mine" | Two doors (D1). Their order, not ours; no month headings imposing our calendar |
| 6 | Opens one, looks properly | absorption | Same day page, same plate, same zoom |
| 7 | Never sees a paywall over it | trust, invisibly | The thing persona 6 lost, that we never take |
| 8 | Reinstalls the app one day | **would have been betrayal** | "Kept on this device — free, and yours" was on the page from day one, so the limit was stated before it was hit (D4) |

Steps 7 and 8 are the two with almost no code behind them and they are the ones the category
is decided on. Step 7's enforcement is `decisions/0005` plus the test that the collection
needs no identity beyond a cookie. Step 8's is one line of `.coda__note` and the fact that
it ships on day one rather than after the first complaint.

**Time horizons.** 5 seconds: the control is recognisable as an action. 5 minutes: the
collection is reachable, ordered by the reader, and free. 5 years: the reader was told what
holds it. That third row is the one the plan was missing before review.

---

## Steps

0. **Story 0007 ships first** — public pages stop emitting `Set-Cookie`. Not part of this
   branch. Nothing below is safe to deploy before it lands.
1. **Extract `days/_row.html.erb`** from `days/index.html.erb`, render it from `/days`, own
   commit, archive tests green and unchanged. Refactor before feature.
2. Migration (`collector_digest`), `Favorite` model, fixtures, model tests.
3. `FavoritesController#control` + the three private cookie methods + the frame partial. The
   read path before the write path, so the mint-and-cache assertions land first.
4. `#create` / `#destroy`, the fallback mint, the race rescue, idempotent destroy,
   `autofocus` on write responses only.
5. Mount the frame in `daily/_day.html.erb`, gated on `chrome:` — `:front_door` and
   `:archive` only, never `:preview`. Assert the front-door ETag is unchanged between a
   visitor with a collection and one without.
6. `#index` + `favorites/index.html.erb`, reusing `.days`; the orphan row and its `Remove`;
   the coda with the device line; the empty state.
7. The two doors: `Your collection →` in the `/days` coda (countless, no frame),
   `The days behind you →` in the `/collection` coda.
8. `.keep` CSS. `DESIGN.md`: the component, the left-grouped rule, the 44px rule, and the
   explicit note that the kept state carries **no glyph**.
9. `decisions/0005-favorites-free-and-device-local.md` (R4), including the `/feed` trigger.
10. `bin/ci` green, then dogfood at 1280 and 375: keep, unkeep, tab to the toggle and press
    it, restart the browser, delete a pick out from under a kept work.

---

## Tests

**Caching and identity** (`test/integration/favorites_test.rb`) — the ones that matter most:
- **adding the keep frame puts no `Set-Cookie` back on `/`, `/days` or `/days/:date`**, with
  and without a collector cookie present — the guard that 0006 does not regress story 0007;
- the front door's **ETag is identical** for a visitor with three kept works and a visitor
  with none, and its body is byte-identical;
- the control endpoint returns `private, no-store` and `Vary: Cookie`;
- `/collection` returns `private, no-store`;
- **`control` with no cookie mints one** and renders the unkept state (eng review, issue 2);
- **`control` with a cookie does not mint a second one**;
- **the Set-Cookie carries a far-future expiry, `httponly` and `same_site=lax`** — this, not
  a fake browser restart, is what proves the collection survives quitting the app. Dropping
  `.permanent` later fails here (eng review, issue 6);
- **replaying that cookie value on a fresh session returns the same collection** — the
  returning-reader path, tested at the level we actually control;
- `create` with no cookie still works, via the fallback mint;
- **the stored column is a digest, never the raw token** — read a row back and assert it does
  not equal the cookie value.

**Toggle**:
- `create` then `control` renders kept; `destroy` then `control` renders unkept;
- `create` twice is one row, not a 500 (`RecordNotUnique` path, forced);
- `destroy` on something not kept renders unkept and does not 404;
- two different cookies do not see each other's state on the same painting, **and
  `/collection` under one cookie never shows the other's rows**;
- a painting id that does not exist 404s;
- CSRF: a POST without a token is rejected. **This test must set
  `ActionController::Base.allow_forgery_protection = true` for its duration and restore it in
  an `ensure`** — `config/environments/test.rb:29` disables forgery protection globally, so
  written the obvious way the assertion can never fail (outside voice).

**Collection** (`test/integration/favorites_test.rb`):
- rows are newest-kept first, **not** publication order;
- **the row for the pick the front door is showing links to `/`, not `/days/:date`** — and
  the same on a gap day, where the front door is holding an older pick over (eng review,
  issue 3);
- a kept work whose pick was deleted renders unlinked, with a working `Remove`;
- removing an orphan actually removes it;
- empty state renders the promise line **and** the "Keep this sits under every artwork" line;
- the frame's `7 kept →` link is absent at zero and present at one;
- **`/days` carries `Your collection →` at zero and at seven, and the two responses are
  byte-identical** — the countless door must not become per-visitor by accident (D1);
- `/collection` carries `The days behind you →` and `Today →`;
- the coda carries the device line (D4);
- the masthead aside reads "7 works", not "7 kept";
- rows are `<li>` in `<ol>` with full accessible link names;
- thumbnails request `size: 240`, not the original (ISSUE-001 regression guard).

**Chrome modes** (`test/integration/admin/daily_picks_test.rb`):
- the curator's preview renders **no** keep frame and no collection link (D2);
- `/` and `/days/:date` both render the frame.

**Row partial — REGRESSION, mandatory** (`test/integration/days_test.rb`,
`test/system/days_test.rb`): the existing archive tests stay green **unchanged** across the
`days/_row.html.erb` extraction. That is the regression proof; the extraction commit is not
allowed to touch them. Plus one new assertion that `/days` and `/collection` render the same
row structure, so the two cannot silently drift apart again.

**Model** (`test/models/favorite_test.rb`): uniqueness scoped to the digest; digest required;
`collected_by`.

**System** (`test/system/favorites_test.rb`):
- keep from the front door: the words change, the URL does not, the page does not scroll;
- **keyboard: tab to the toggle, press it, and focus is still on the toggle afterwards**
  (D3 — the whole point of `autofocus` on the write responses);
- the lazy frame landing on scroll does **not** move focus;
- the kept work is at `/collection`, reachable from the day page's frame link **and** from
  `/days`;
- at 375 the toggle, the collection link and the orphan `Remove` each measure ≥44px, and the
  kept row does not wrap;
- the day page still zooms and still reads with the frame present (parity guard).

Persistence is **not** tested here. "A new Capybara session with the same cookie jar" is not
a thing — a new session launches a clean browser profile, so that test would be quietly
weakened until it passed. The real contract is the cookie's attributes plus the replay, both
asserted at integration level above (eng review, issue 6).

---

## Failure modes

| Codepath | Realistic production failure | Test? | Error handling? | User sees |
|---|---|---|---|---|
| Public page + shared cache | Thruster's default 64MB cache stores `public` HTML carrying `Set-Cookie` and replays one reader's session | **yes** — story 0007's assertions, plus 0006's guard that the frame does not reintroduce it | yes — **story 0007**, ships first | Nothing. That is what 0007 exists to prevent |
| Two tabs, cold start | Both mint a token, one row orphaned under an id nobody holds, both tabs say "Kept" | **yes** — mint-on-`control` assertions | yes — identity established on the fragment read (issue 2) | Both works kept, both visible |
| Collection row for the current pick | Links to the dated URL and 301s to `/` on every tap | **yes** — canonical-link test, plus a gap-day variant | yes — `@current` passed to `day_link_path` (issue 3) | One request, canonical URL |
| DB copy leaks | Raw tokens in a dump are working credentials for other readers' collections | **yes** — the stored value is asserted not to equal the cookie | yes — SHA256 digest at the lookup boundary (outside voice) | Nothing replayable |
| Turbo snapshot restore | Back-navigation shows a remembered `Kept` that no longer matches the server | no — **accepted** | none | A sub-second stale label that self-corrects. Watched for at dogfood (issue 7) |
| Painting deleted | FK restricts, so a kept painting cannot be removed from the pool | no — `db/seeds.rb` only upserts, nothing deletes paintings | invariant stated in the data model | N/A |
| `#create` double-tap / two tabs | Unique index violation | yes | yes — rescue `RecordNotUnique` as success | Kept, once |
| `#destroy` on a stale frame | Row already gone | yes | yes — `destroy_by` is idempotent | Unkept state |
| Frame request fails (offline) | Turbo cannot load the frame | no — hard to force deterministically | none needed | Empty 44px of space; the page is otherwise whole |
| Frame replacement drops focus | Keyboard/SR user presses Keep, focus falls to `<body>` | **yes** (system test) | yes — `autofocus` on write responses only (D3) | Focus stays on the toggle, new state announced |
| Lazy frame announces itself | SR user scrolls past the credit and hears an unprompted string | **yes** (system test) | yes — no live region (D3) | Nothing until they act |
| Curator preview | Keep button on unpublished work, curator rows pollute usage data | **yes** (integration) | yes — `chrome:` gate (D2) | No control in preview |
| Curator deletes a pick under a kept work | Row has no day to link to | yes | yes — unlinked row + `Remove` | The work, unlinked, removable |
| Cookie evicted by iOS storage pressure | Collection becomes unreachable | no — cannot be simulated | **none** | An empty collection. **This is the accepted device-local risk, not a handled case.** |
| Collector token guessed | Another reader's collection read | no | 24 random base58 chars, signed, httponly | Not reachable |
| Painting blob unreadable on a collection row | vips/CDN failure | inherited from `artwork_src` | yes — existing narrow logged rescue | CDN image, or a collapsed thumbnail |

**Critical gaps (no test AND no handling AND silent): one, deliberately** — cookie eviction.
It is named in `story.md`, in the decision entry, and has a written trigger. The Turbo
snapshot row is untested and unhandled but **not silent and not critical**: it is a visible,
self-correcting label, accepted at eng review with a dogfood check rather than a mitigation
that would slow every back-navigation. Everything else is either tested or cannot happen.

---

## Parallelization

| Step | Modules touched | Depends on |
|---|---|---|
| Story 0007 | `app/views/layouts/`, `app/controllers/admin/` | — (separate branch, ships first) |
| Row extraction | `app/views/days/` | — |
| Model + migration | `db/`, `app/models/`, `test/fixtures/` | — |
| Controller + frame | `app/controllers/`, `app/views/favorites/`, `config/routes.rb` | model |
| Day page mount | `app/views/daily/` | frame |
| Collection page | `app/views/favorites/` | model, row extraction |
| Two doors | `app/views/days/`, `app/views/favorites/` | row extraction, collection |
| CSS + `DESIGN.md` | `app/assets/`, `DESIGN.md` | frame, collection |

Lane A: model → controller → mount. Lane B: row extraction → collection page → two doors.
They meet at the CSS. Story 0007 is not a lane — it is a prerequisite on its own branch.
One session's work per lane; not worth a worktree, noted because the two lanes genuinely do
not touch the same directories until the end.

---

## NOT in scope (considered and deferred, with rationale)

- **Accounts / cross-device sync.** Full reasoning in the identity table above. Trigger: the
  first real user who asks for their collection on a second device.
- **Export.** The honest answer to device-local, and premature while the collection holds
  one work. Revisit with the accounts trigger.
- **Keep on `/feed` (D9).** Deferred, with the trigger written rather than the objection
  implied. Every day page ends with "Wander the full gallery →", so after this ships `/feed`
  is the one room in the product where you can look at art and not keep it. That is a real
  dead end and it is accepted on purpose: a wishlist over 110 museum works is persona 4's
  reference browser and persona 5's taste filter, both **New-slot candidates for the Phase 3
  gate**, and adding it here would spend the single New slot months early and by accident.
  It would also mean 110 per-visitor fragments on one infinitely scrolling public page.
  **Trigger to reopen:** the Phase 3 gate, or a real user asking for it in one of BET.md's
  five conversations — not a hunch mid-build. Goes in `decisions/0005` so the boundary is
  checkable rather than remembered.
- **Cutting "Wander the full gallery →" to remove the dead end.** Considered and rejected:
  it deletes the only discovery path into 110 seeded works to solve a problem nobody has
  reported.
- **Keep on `/days` rows.** Thirty private fragments on a public list, plus a second
  interactive element inside a row that is already one link. Saves one tap.
- **Per-row remove on the collection.** Same nesting problem. **Trigger:** a user asks, or a
  collection passes ~50 rows — then the row link narrows to the text column and the button
  sits beside it.
- **A kept count in the masthead.** Per-visitor state in a header rendered on every public,
  cached page. Would require a frame in the masthead of every screen.
- **Undo after unkeeping.** A toast is exactly the interrupt rule 5 and Better bar 4 forbid,
  and the toggle is its own undo.
- **`[collector_digest, created_at]` index.** Trigger written: 500 rows in one collection.
- **A `Collecting` concern.** Dropped at eng review: one includer, and every candidate second
  includer is deferred by this same list. Three private methods on `FavoritesController`
  instead. Extract when a second caller exists, not before.
- **Disabling Turbo's page snapshot on day pages.** Considered at eng review after the
  outside voice raised it. A restored snapshot can briefly show a stale kept label; the fix
  costs every back-navigation its instant preview, which is a constant speed cost against a
  rare cosmetic one. **Accepted, with a dogfood check written into step 10** rather than a
  mitigation. Revisit if the flash is real on a device.
- **Analytics on keeps.** Not just out of scope — actively forbidden, and that commitment is
  what the gate-6 privacy-label determination will rest on.

---

## What already exists (reuse, don't reinvent)

| Need | Already in the repo | Reused or rebuilt |
|---|---|---|
| The list row | `.days` — 19 lines of **inline** ERB at `days/index.html.erb:23-41`, no partial | **Extracted to `days/_row.html.erb` first**, then rendered by both pages. "Reuse" was not actionable until it existed (eng review, issue 4) |
| Admin boundary | `Admin::BaseController` — already owns HTTP basic auth for the namespace | Story 0007 hangs the admin layout off it, so no future admin controller re-inherits the public one |
| Test env quirk | `config/environments/test.rb:29` disables forgery protection globally | Re-enabled inside the one CSRF test, or that test can never fail |
| Thumbnail sizing | `artwork_src(painting, size: 240)` | Reused; ISSUE-001 already litigated this |
| Canonical day URL | `day_link_path(pick, current)` | Reused — collection rows must not 301 either |
| Small-caps affordance | `.caps-link` (0.78rem, uppercase, 0.2em, inherits `--gold`) | Reused as the toggle's scale |
| Kept-state mark | `✦`, the ornament | **Deliberately NOT reused** (D7) — it is the product's one ornament and rule 6 says so. Words carry the state instead |
| Separator | the `·` in `.label__credit` and `.days__date--now`'s "Today · " | Reused in `Kept · Remove` — no new punctuation |
| Count idiom | `pluralize(@picks.size, "day")` → "14 days" in `.masthead__aside` | Reused for "7 works"; the link's "7 kept →" follows the same count-first, no-parentheses shape (D6) |
| 44px pattern | `.walk__step { min-height: 44px }` — the exact fix from ISSUE-002 (commit 866bbc2) | Copied onto `.keep__toggle` / `.keep__link`, because `.caps-link` still has no min-height of its own |
| Coda copy pattern | `.coda__line` + `.coda__note` + `.caps-link` | Reused for the collection's ending and the device line |
| Empty state | `.page--empty` + `.coda` + ornament, and `/days`' "The days will collect here." | Reused, and the promise phrasing is deliberately parallel (D5) |
| Long titles | `Painting#long_title?` + `--long` | Reused at list scale |
| Chrome modes | `_day.html.erb`'s `chrome:` symbol, built in story 0003 for exactly this class of problem | Reused — the preview gate is a fourth condition on an existing branch (D2) |
| Turbo | `turbo-rails` already in the Gemfile | Reused; no new dependency, no new Stimulus controller |
| Frames precedent | the archive's lazy Turbo frame in `/feed` | Same mechanism, private response |

**No new gems. No new Stimulus controller. No JavaScript written for this story.**

---

## Approved Mockups

Built in the real linen CSS with a real MIA work (Bonnard, *Dining Room in the Country*) and
a real hand-written note — the same method story 0003 used, because AI-generated mockups
would fight this palette rather than test it. Each sheet shows the unkept state, the kept
state, and the same foot on a past day where prev / next / today already live.

| Screen | Mockup | Direction | Notes |
|---|---|---|---|
| Day-page foot, 1280 | `~/.gstack/projects/tasteMaker/designs/favorites-keep-control-20260804/variant-b-final.png` | **Approved** — "the wall label's last row": left-aligned, gold, inside `.label` | Final copy. Build from this plus D8 (left-grouped, not spread) |
| Day-page foot, 375 | `…/variant-b-final-375.png` | Same row, unchanged | Source of the measured numbers in Responsive |
| Rejected: own block | `…/variant-a-own-block.png` | Centred block above the coda | Two closing beats; `--ink-dim` unkept state read as a caption |
| Rejected: in the coda | `…/variant-c-in-coda.png` | Folded into the coda link row | Measured 3 items → 3 lines at 375; asks for commitment after "See you tomorrow." |
| Source HTML | `…/variant-b-final.html` | — | Regenerate or re-measure from this rather than re-deriving |

## Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific finding above.

**T0 — story 0007 ships first.** `specs/0007-no-session-cookie-on-public-pages/`. Not a task
in this branch; a prerequisite for deploying it.

- [ ] **T1 (P1, human: ~45min / CC: ~15min)** — `days/_row.html.erb` — extract the archive
      row, render it from `/days`, own commit
  - Surfaced by: **eng review, issue 4** — "reuses `.days` wholesale" had nothing to reuse;
    the row is 19 inline lines at `days/index.html.erb:23-41` carrying the a11y contract and
    the ISSUE-001 240px fix
  - Files: `app/views/days/_row.html.erb`, `app/views/days/index.html.erb`
  - Verify: the existing archive integration + system tests stay green **unchanged**
    (mandatory regression proof)
- [ ] **T2 (P1, human: ~45min / CC: ~15min)** — `Favorite` — migration on
      **`collector_digest`**, model, fixtures
  - Surfaced by: plan (painting-keyed, so an editorial delete never removes a kept work) +
    **outside voice** (a raw token in the DB is a bearer credential; this column is the one
    thing here that is expensive to change after launch)
  - Files: `db/migrate/`, `app/models/favorite.rb`, `test/fixtures/favorites.yml`
  - Verify: uniqueness scoped to the digest; a stored row's value is not the cookie value
- [ ] **T3 (P1, human: ~1h / CC: ~20min)** — `FavoritesController#control` + the three private
      cookie methods — the read path, its cache headers, and **minting**
  - Surfaced by: **eng review, issue 2** — minting on the first write loses a row silently
    when two cold-start tabs both keep something; **issue 5** — a concern with one includer
    is a file boundary standing in for a code boundary
  - Files: `app/controllers/favorites_controller.rb`, `config/routes.rb`,
    `app/views/favorites/_control.html.erb`
  - Verify: `private, no-store`, `Vary: Cookie`; a first GET mints, a second does not; the
    Set-Cookie carries a far-future expiry, `httponly`, `same_site=lax`
- [ ] **T4 (P1, human: ~45min / CC: ~15min)** — `#create` / `#destroy` with `autofocus` on
      the write responses only
  - Surfaced by: **Pass 2, issue 3** — Turbo replaces the frame, focus falls to `<body>`, and
    the planned `aria-live` would fire on lazy insert instead of on action
  - Files: `app/controllers/favorites_controller.rb`, `app/views/favorites/_control.html.erb`
  - Verify: keyboard system test — press the toggle, focus is still on the toggle
- [ ] **T5 (P1, human: ~30min / CC: ~10min)** — mount the frame in `_day.html.erb`, gated on
      `chrome:` — never `:preview`
  - Surfaced by: **Pass 2, issue 2** — the plan's "no other change" would give the curator a
    live keep button on unpublished work and contaminate the first usage data
  - Files: `app/views/daily/_day.html.erb`
  - Verify: preview renders no frame; `/` and `/days/:date` do; front-door ETag unchanged
- [ ] **T6 (P1, human: ~1h / CC: ~20min)** — `/collection` — rows via the extracted partial,
      orphan row + `Remove`, coda, empty state, **and `@current`**
  - Surfaced by: **design Pass 3, issues 4 and 5** (no durability line; an empty state that
    reported an absence on what is now a first impression) + **eng review, issue 3**
    (`day_link_path` needs `DailyPick.current` or the front-door row 301s on every tap)
  - Files: `app/controllers/favorites_controller.rb`, `app/views/favorites/index.html.erb`
  - Verify: promise + context + action in the empty state; device line in the coda; masthead
    aside reads "7 works"; the current-pick row links to `/`, including on a gap day; picks
    resolved through `index_by`, not a find-in-loop
- [ ] **T7 (P1, human: ~20min / CC: ~5min)** — the two doors
  - Surfaced by: **Pass 1, issue 1** — the collection had exactly one entrance, at the bottom
    of a different page, behind a lazy frame
  - Files: `app/views/days/index.html.erb`, `app/views/favorites/index.html.erb`
  - Verify: `/days` renders `Your collection →` and is byte-identical at zero and at seven
- [ ] **T8 (P1, human: ~45min / CC: ~15min)** — `.keep` CSS exactly as specified
  - Surfaced by: **Pass 5 and 6, issues 7 and 8** — the `✦` overload, and 466px between two
    related items at 1280
  - Files: `app/assets/stylesheets/application.css`
  - Verify: `flex-start`, `gap: 1.6rem`, `margin-top: 2.2rem`, 44px targets, no glyph
- [ ] **T9 (P2, human: ~20min / CC: ~5min)** — copy — `Kept · Remove` and `7 kept →`
  - Surfaced by: **Pass 4, issue 6** — parenthetical counts are badge habit; the product
    writes counts as "14 days"
  - Files: `app/views/favorites/_control.html.erb`
  - Verify: no parentheses anywhere in the feature
- [ ] **T10 (P2, human: ~20min / CC: ~5min)** — `DESIGN.md` — the `.keep` component, the
      left-grouped rule, the 44px rule, and an explicit "no glyph in the kept state" line
  - Surfaced by: **Pass 5** — a new component without a line in the file drifts, and the
    next person will reach for `✦` for exactly the reason I did
  - Files: `DESIGN.md`
  - Verify: `bin/rails test test/system/design_test.rb`
- [ ] **T11 (P2, human: ~30min / CC: ~10min)** — `decisions/0005-favorites-free-and-device-local.md`,
      carrying **all three deferral triggers**
  - Surfaced by: **Pass 7, issues 9 and 10** and R4. No `TODOS.md` is created — this project
    tracks work in `specs/` and `decisions/`, and a list with nothing enforcing it is the
    "infrastructure for later" pattern CLAUDE.md names. The triggers therefore live where
    someone will be standing when they fire
  - Must contain: free-forever + device-local position; the **accounts/export** trigger (a
    real user asks for their collection on a second device); the **`/feed`** trigger (Phase 3
    gate, or a real user asking in one of BET.md's five conversations); the **per-row remove**
    trigger (a user asks, or a collection passes ~50 rows)
  - Files: `decisions/0005-favorites-free-and-device-local.md`
  - Verify: falsifiable, time-bound prediction present; all three triggers written
- [ ] **T12 (P2, human: ~15min / CC: ~5min)** — refresh the `chrome:` diagram comment in
      `_day.html.erb`
  - Surfaced by: **eng review** — `app/views/daily/_day.html.erb:1-17` holds an ASCII table of
    what differs across the three chrome modes. Adding a fourth differing thing (the keep
    frame, absent in `:preview`) makes it stale, and a stale diagram misleads worse than none
  - Files: `app/views/daily/_day.html.erb`
  - Verify: the table's column list matches what the template actually branches on

---

## Deviations (added during build)

- 2026-08-04: **the collection link inside the frame navigated the frame, not the page.**
  A link inside a `<turbo-frame>` targets that frame by default, so tapping `1 kept →`
  loaded the whole collection page into a 44px box and the reader went nowhere. Needs
  `data: { turbo_frame: "_top" }`. Caught by the system test, not by any integration test —
  an integration `get` on the link's href would have passed.
- 2026-08-04: **`Painting.find` does not raise out of an integration test.** Rails' test env
  rescues `RecordNotFound` and `InvalidAuthenticityToken` into 404 and 422 responses, so the
  planned `assert_raises` assertions never fire. They assert on the response instead.
- 2026-08-04: **`with_forgery_protection` also had to wrap the no-`Set-Cookie` tests, and it
  lives on `ActiveSupport::TestCase`, not `ActionDispatch::IntegrationTest`.** The plan only
  applied it to the CSRF test. But `csrf_meta_tags` returns nil without ever calling
  `form_authenticity_token` when protection is off, so with the suite default the *old*
  layout emitted no cookie either — every cookie assertion would have passed against the
  unfixed code. The system test needed it too, which is why it moved up a class.
- 2026-08-04: **two dogfood findings, neither in any plan.** The collection's coda is the
  first in the product with two ways out, and two `.caps-link`s sharing a line with only
  whitespace between them read as one string; they now get `1.6rem` and, per the new
  DESIGN.md rule 9, the 44px height `.caps-link` never carried. And the orphan row's title
  was still `--gold`, the product's "this navigates" colour, on the one row that navigates
  nowhere — stepped to `--ink`, leaving `Remove` as the only gold on it.
- 2026-08-04: `_row.html.erb` split again into `_row` + `_row_body`. The linked and unlinked
  shapes share their whole interior, and one `if` around 12 lines of duplicated markup was
  the alternative.

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues absorbed | 16 raised: 5 stale-plan artifacts, 2 verified and folded, 2 raised as cross-model tension, rest folded as corrections |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAN | 8 issues, 1 accepted critical gap, scope reduced (session-cookie fix → story 0007) |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | score: 6/10 → 9/10, 9 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** verified two of its claims directly against the repo and both held —
`config/environments/test.rb:29` disables forgery protection globally, so the planned CSRF
test could never fail; and `Admin::DailyPicksController#preview` renders with no explicit
layout, so after the layout split the curator's preview would render in admin chrome and
stop being the reader's page. It also independently found the `Admin::BaseController` layout
placement, the painting-FK invariant, and the overconfident privacy-label claim. Five of its
sixteen points were the plan lagging decisions made minutes earlier in the same session.

**CROSS-MODEL:** the first-party review found the two-tab token race and the missing
`DailyPick.current`; Codex found neither. Codex found the untestable CSRF assertion and the
preview-layout regression; the first-party review found neither. Two genuine tensions went to
the user: Turbo's snapshot cache (accepted with a dogfood check, not mitigated) and raw-token
storage (digest adopted). Both reviews independently reached the same conclusion on
`Admin::BaseController`.

**VERDICT:** DESIGN + ENG CLEARED — ready to implement, **after story 0007 ships**.

NO UNRESOLVED DECISIONS
