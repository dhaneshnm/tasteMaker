class CreatePaintings < ActiveRecord::Migration[8.1]
  def change
    create_table :paintings do |t|
      t.integer :mia_id
      t.string :title
      t.string :artist
      t.string :life_date
      t.string :dated
      t.string :medium
      t.string :dimension
      t.string :country
      t.string :culture
      t.string :department
      t.text :description
      t.string :creditline
      t.string :accession_number
      t.integer :image_width
      t.integer :image_height
      t.string :image_url_full
      t.string :image_url_800
      t.integer :feed_order

      t.timestamps
    end
    add_index :paintings, :mia_id, unique: true
    add_index :paintings, :feed_order
  end
end
