# Story 0018. One indexed lookup for `/artists/:slug` instead of
# `Painting.distinct.pluck(:artist)` plus a `parameterize` call per row, per
# request.
#
# Calls the model, not a copy of its logic — the flatten-descriptions
# migration (20260815153227) already burned this: a duplicated regex there is
# how `db/seeds.rb` came to carry a stale AIC User-Agent. `Painting.
# artist_slug_for` is the one implementation the write path, the backfill, and
# any future migration all read.
#
# `update_all`, not `save!` per row: these rows are already valid, and a
# backfill should not bump `updated_at` (which the ETags on `/` and `/days`
# key off — `update_all` never touches timestamps) or run every other
# callback and validation for a single derived column.
class AddArtistSlugToPaintings < ActiveRecord::Migration[8.1]
  def up
    add_column :paintings, :artist_slug, :string

    # Grouped by the SLUG each distinct artist string resolves to, not one
    # UPDATE per row: two spellings sharing a slug (accent variants) share
    # one query, and the whole pool backfills in ~1,000 statements instead of
    # ~2,000. The index is built after, over final data, rather than being
    # incrementally maintained through every one of those writes.
    Painting.reset_column_information
    Painting.distinct.pluck(:artist).group_by { |artist| Painting.artist_slug_for(artist) }.each do |slug, artists|
      Painting.where(artist: artists).update_all(artist_slug: slug)
    end

    add_index :paintings, :artist_slug
  end

  def down
    remove_column :paintings, :artist_slug
  end
end
