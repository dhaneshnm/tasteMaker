class CreateDailyPicks < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_picks do |t|
      t.references :painting, null: false, foreign_key: true, index: { unique: true }
      t.date :scheduled_on, null: false
      t.text :blurb, null: false

      t.timestamps
    end

    add_index :daily_picks, :scheduled_on, unique: true
  end
end
