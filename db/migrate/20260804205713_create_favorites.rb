class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      # The SHA256 of the reader's cookie token, never the token itself. The
      # cookie is a bearer credential — anyone holding it is that reader — so a
      # copy of it here would make a backup or a dump a set of working
      # credentials for other people's collections. Every lookup starts from the
      # cookie anyway, so hashing at the boundary costs one call and changes
      # nothing else.
      t.string :collector_digest, null: false

      # Keyed to the painting, not the daily pick. A pick can be rescheduled or
      # deleted by the curator, and a pick-keyed favorite would be destroyed by
      # the foreign key when that happened — an editorial action silently taking
      # something a reader kept. The FK below restricts painting deletion, which
      # is safe because db/seeds.rb only ever upserts by mia_id.
      t.references :painting, null: false, foreign_key: true

      t.timestamps
    end

    # Both the correctness rule (one row per work per reader, whatever races) and
    # the lookup index. No [collector_digest, created_at] index yet: this covers
    # the WHERE, and sorting a handful of rows is free. Add one when a single
    # collection passes 500 rows.
    add_index :favorites, %i[collector_digest painting_id], unique: true
  end
end
