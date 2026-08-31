class CreateImpressions < ActiveRecord::Migration[8.0]
  def change
    create_table :impressions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :painting, null: false, foreign_key: true
      # 280 is the field's maxlength too — one line, not an essay. The model
      # re-validates; the limit here keeps the DB honest about the contract.
      t.string :body, null: false, limit: 280
      t.timestamps
    end

    # Write-once per painting (story 0032, D6). Load-bearing assumption (eng
    # OV8): `daily_picks.painting_id` is itself UNIQUE — a painting is never
    # picked twice — so "one impression per painting" and "one impression per
    # day it appeared" are today the same statement. If one-day-per-painting
    # is ever relaxed, this index is the contract that stops a years-old line
    # being the only capture allowed against a re-run day's rewritten note.
    add_index :impressions, [ :user_id, :painting_id ], unique: true
  end
end
