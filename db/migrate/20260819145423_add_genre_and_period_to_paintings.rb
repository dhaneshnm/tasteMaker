# Story 0022 Release 1. Two nullable string columns, not a join table —
# see specs/0022-what-kind-and-when/plan.md D1. `genre` ships empty until
# Release 2 fills the manifest; `period` is written at seed time by
# lib/pool/period_bucket.rb, reseed-safe by construction.
class AddGenreAndPeriodToPaintings < ActiveRecord::Migration[8.1]
  def change
    add_column :paintings, :genre, :string
    add_column :paintings, :period, :string
    add_index :paintings, :genre
    add_index :paintings, :period
  end
end
