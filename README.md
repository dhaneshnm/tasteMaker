# Tastemaker

An Instagram-style infinite-scroll feed of famous paintings — public-domain
works from the [Minneapolis Institute of Art](https://collections.artsmia.org),
each with the curatorial text that explains what it is and why it matters.

No users, no likes, one view: the gallery.

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
Image resizing uses macOS `sips`, so no imagemagick/libvips install is needed
(on Linux, seed with `FAST=1` or add a resize tool).

## Data

`db/seeds/mia_paintings.json` holds 110 curated works — chosen from the
museum's ~1,400 public-domain paintings for having substantial curatorial
descriptions, good images, and a mix of artists and departments (European,
Asian, Americas). Metadata is CC0 from
[artsmia/collection](https://github.com/artsmia/collection); images come from
the museum's public CDN at seed time.

## How the feed works

`PaintingsController#index` serves 10 paintings per page. Each page ends in a
`turbo_frame_tag` with `loading: :lazy` pointing at the next page; when the
frame scrolls into view, Turbo fetches it and the next batch (plus the next
sentinel) replaces the spinner. The last page renders a colophon instead.
No custom pagination JS at all.
