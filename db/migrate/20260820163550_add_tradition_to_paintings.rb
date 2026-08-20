# Story 0024. A third nullable string column, same shape as 0022's genre/period
# (specs/0022-what-kind-and-when/plan.md D1): canonical display value stored,
# slug derived at read time, written at seed time by lib/pool/tradition.rb —
# reseed-safe by construction, no backfill task to forget on a fresh seed.
class AddTraditionToPaintings < ActiveRecord::Migration[8.1]
  def change
    add_column :paintings, :tradition, :string
    add_index :paintings, :tradition
  end
end
