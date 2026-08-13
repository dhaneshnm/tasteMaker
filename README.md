# Tondo

One public-domain artwork a day, with a short hand-written note on why it
matters. Works come from the [Minneapolis Institute of
Art](https://collections.artsmia.org); the notes are written by hand, never
generated.

- `/` — **Artwork of the Day.** The front door: one painting, one note, one date.
- `/feed` — the original infinite-scroll gallery, one quiet link away.
- `/admin/daily_picks` — the curator's queue (HTTP basic auth).

## Publishing a day

The queue lives at `/admin/daily_picks`. Pick a painting, set a date, write the
note; the form nudges toward 60–180 words and previews the real page before you
publish. A day with nothing scheduled keeps the previous artwork up, dated
honestly, rather than going blank.

Set the password before the site is reachable by anyone else:

```sh
bin/rails credentials:edit     # curator:\n  password: ...
export CURATOR_PASSWORD=...    # or this, for local and CI runs
```

## Stack

- Ruby on Rails 8.1 + Hotwire (Turbo lazy frames drive the infinite scroll;
  two small Stimulus controllers handle the scroll-in reveal and the
  "More" caption toggle)
- SQLite (schema has nothing SQLite-specific — swap `database.yml` and the
  `sqlite3` gem for `pg` when it's time for Postgres)
- Active Storage on local disk for painting images

## Setup

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed        # metadata + full-quality images, resized to 1600px (~50MB)
bin/rails server
```

Seed variants:

```sh
FAST=1 bin/rails db:seed         # 800px images, much faster download
SKIP_IMAGES=1 bin/rails db:seed  # metadata only; feed falls back to the museum CDN
```

Seeding is idempotent — re-running only fills in whatever is missing.
Image resizing prefers libvips (already in the Dockerfile) and falls back to
macOS `sips`, so no local install is needed on either. With neither available
the seed refuses to run rather than filling the disk with full-size plates.

## Data

`db/seeds/paintings.json` holds the 2,000 works the app ships with, drawn from
four open-access collections: the Metropolitan Museum of Art, the Art Institute
of Chicago, the Cleveland Museum of Art and the Minneapolis Institute of Art.
Images come from each museum's CDN at seed time; all metadata is CC0.

The pool is not hand-picked. `lib/pool/curator.rb` holds a quota table — range
beyond Europe and North America, a per-artist ceiling, a cap on any one museum
or region, a floor of works carrying readable museum text, a resolution floor —
and `db/seeds/pool_report.md` is the receipt showing every bar holding.
`test/lib/pool_quota_test.rb` fails the build if a reseed regresses any of them.

Rebuild the pool with:

```
bin/rails pool:mirror   # ~15K painting records from all four museums, cached in tmp/
bin/rails pool:curate   # applies the quota table, writes the manifest and report
bin/rails db:seed       # downloads plates for the 2,000 selected (~1 GB), resumable
```

`pool:curate` proves every plate it selects is actually reachable before writing
the manifest — museums publish public-domain rights for images that then 403.

## How the feed works

`PaintingsController#index` serves 10 paintings per page. Each page ends in a
`turbo_frame_tag` with `loading: :lazy` pointing at the next page; when the
frame scrolls into view, Turbo fetches it and the next batch (plus the next
sentinel) replaces the spinner. The last page renders a colophon instead.
No custom pagination JS at all.
