# Identity stops being "the museum's id" and becomes "which museum, and its id".
#
# Story 0013: the pool grows from one collection (Minneapolis) to four (Met, Art
# Institute of Chicago, Cleveland, Minneapolis). Object ids collide freely across
# museums — Met 45734 and MIA 45734 are different paintings — so the unique index
# has to move from `mia_id` alone to the pair.
#
# The 110 rows already on disk keep their ids, their Active Storage attachments
# and their place in the feed. Nothing is re-downloaded.
class AddSourceToPaintings < ActiveRecord::Migration[8.1]
  def up
    # SQLite renames a column by rebuilding the table, and carries the unique
    # index across under its new name — so this drops it by column, not by the
    # old `index_paintings_on_mia_id` name, which no longer exists by now.
    rename_column :paintings, :mia_id, :source_id
    remove_index :paintings, :source_id

    add_column :paintings, :source, :string
    # Every row that exists when this runs came from db/seeds/mia_paintings.json.
    execute "UPDATE paintings SET source = 'mia'"
    change_column_null :paintings, :source, false

    # Recorded per row, not per source: MIA states image rights on each object
    # (`rights_type`, `Rights_Image_Display`) and they are not uniform, so the
    # licence a stored image was taken under has to travel with the image.
    add_column :paintings, :image_license, :string
    execute "UPDATE paintings SET image_license = 'Public Domain'"

    add_index :paintings, [ :source, :source_id ], unique: true
  end

  def down
    remove_index :paintings, [ :source, :source_id ]
    remove_column :paintings, :image_license
    remove_column :paintings, :source
    rename_column :paintings, :source_id, :mia_id
    add_index :paintings, :mia_id, unique: true
  end
end
