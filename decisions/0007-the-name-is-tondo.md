# 0007 — The name is Tondo

Date: 2026-08-10

Position: the product is renamed from **Tastemaker** to **Tondo** — Italian,
clipped from *rotondo*, "round": a painting made in a circle. The App Store name
field is `Tondo: Daily Art` (16 of 30 characters) and the subtitle is
`One painting a day, explained` (29 of 30). The mark is a rose window in the
`DESIGN.md` tokens; the identity is locked in that file's Brand section and does
not get reopened.

"Tastemaker" is not a bad word. It is the wrong word for a bet whose *only*
distribution channel is App Store search. Nobody types "tastemaker" with art
intent, so the 30-character name field — the highest-weighted field in App Store
search — would have been spent on a term that ranks for nothing. It is also a
crowded generic brand term across media, food and fashion, and it points at the
curator's status rather than at the reader's experience, which is backwards for a
product whose whole proposition is *you look at one thing today*.

Tondo was chosen against two alternatives that lost on collision, not on taste.
**Loupe** is already an art app: Loupe LLC's "Loupe — Visual Art Experience"
streams curated artwork, has favourites, and sells prints. Same category, same
features, established mark. **Gesso** is Gesso app, Brooklyn, museum audio guides
for 50+ institutions including the New Museum and ICP — art category again — and
the word is additionally owned in general search by art-supply retail, so we
would fight Liquitex and Blick to rank for our own brand. Tondo's App Store
namesakes are a local-community social feed, a food-packaging service in Bologna,
and a music developer. **Zero art-category overlap.** App Store names are not
unique — only bundle identifiers are — so those three are noise rather than
obstacles.

The costs accepted, stated plainly. **Tondo is also a district of Manila**,
dense and widely associated with poverty; Filipino readers will read the name
that way first. It does not collide in art-intent search and it does not change
what the app is, but it is a real association for a real audience and it is being
accepted knowingly rather than missed. Second, the exact-match domains are gone —
`tondo.com`, `.app`, `.art`, `.today`, `.gallery`, `.studio` are all registered —
so the site lives on a descriptive domain (`dailytondo.com` was unregistered as
of 2026-08-10). Third, the word means nothing to a normal person, which is the
point of a brandable name and also the reason the name field has to carry the
keywords rather than the brand.

Timing is the forcing part. `PRODUCT_BUNDLE_IDENTIFIER` becomes
`com.dhaneshnm.tondo`, and **a bundle identifier cannot be changed once a build
has been uploaded against it**. The Kamal service name, image name and storage
volume change too, and renaming a volume after a deploy orphans the SQLite file
and every reader's collection with it. Both of those are free today and expensive
the moment either happens. Nothing is deployed and nothing is uploaded, so this
is the last cheap moment and the reason the rename jumps the queue ahead of push.

Prediction, falsifiable at the Aug 31 2026 kill review: **the three ranked
keywords in `BET.md` come from the name and subtitle fields — "daily art",
"painting a day", "art" — and none of them come from the word "Tondo" itself.**
If "tondo" ranks and the descriptive terms do not, the naming reasoning above was
wrong about where App Store search weight actually sits, and the next product
should be named for the category rather than for the object.

Enforcement: `test/integration/brand_test.rb` (story 0011) asserts the masthead,
the `<title>` fallback, the PWA manifest and the HTTP basic realm all say Tondo,
and fails if the string "Tastemaker" reappears anywhere under `app/` or
`config/`. Historical files — `SHIPLOG.md`, `decisions/0001`–`0006`, and the
specs for stories already shipped — keep the old name on purpose. Rewriting them
would falsify the record of what was actually built and when.

## Triggers, so these get decided rather than drifted into

- **The trademark search is still outstanding.** USPTO Class 9 (software) and
  Class 41 (education — the tutor). It runs before the rename commit lands, not
  after. A live mark in either class kills this entry and the shortlist reopens
  at Umber or Daymaker, not at Loupe or Gesso.

  **Two checks, not one** (eng review, 2026-08-10). USPTO classes establish
  trademark exposure. They say nothing about whether App Store Connect will
  accept `Tondo: Daily Art` as an app name — Apple enforces its own uniqueness
  on that field, first-come. Both run before the commit; either one failing
  reopens this entry.
- **A second rename.** Renaming after launch throws away whatever keyword
  ranking has accumulated, and `BET.md` allows roughly two and a half weeks of
  indexing before the kill review. After the first App Store submission this
  entry is closed until the kill review, whatever anyone thinks of the name.
- **The Manila reading.** If it surfaces in any of `BET.md`'s five user
  conversations, it becomes evidence rather than a guess and gets weighed then.
  Not before — nobody has opened this app yet.
