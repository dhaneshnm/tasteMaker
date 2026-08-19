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
# `update_column`, not `save!`: these rows are already valid, and a backfill
# should not bump `updated_at` (which the ETags on `/` and `/days` key off) or
# run every other callback and validation for a single derived column.
class AddArtistSlugToPaintings < ActiveRecord::Migration[8.1]
  def up
    add_column :paintings, :artist_slug, :string
    add_index :paintings, :artist_slug

    Painting.reset_column_information
    Painting.find_each do |painting|
      painting.update_column(:artist_slug, Painting.artist_slug_for(painting.artist))
    end
  end

  def down
    remove_column :paintings, :artist_slug
  end
end
