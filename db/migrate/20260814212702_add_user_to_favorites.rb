# Accounts arrived (story 0015), so favorites gain the nullable user_id that
# specs/0006-favorites/plan.md promised for exactly this day. Two keys, two
# columns: a web reader's keep carries user_id, a device's keep carries
# collector_digest, and the model enforces exactly-one-of. No claim path — the
# worlds do not merge (decisions/0011, Q5).
class AddUserToFavorites < ActiveRecord::Migration[8.1]
  def change
    add_reference :favorites, :user, foreign_key: true

    # collector_digest was the only identity; now it is one of two.
    change_column_null :favorites, :collector_digest, true

    # Same correctness rule the digest index enforces, for the account world:
    # one row per work per user, whatever races. Partial, because SQLite indexes
    # every row otherwise and every device keep would carry a NULL entry.
    add_index :favorites, %i[user_id painting_id], unique: true,
      where: "user_id IS NOT NULL"
  end
end
