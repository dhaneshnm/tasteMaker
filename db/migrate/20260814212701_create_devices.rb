# The device key (story 0015). One row per registered iOS install — the SHA256
# of the Keychain UUID, never the UUID itself, for the same reason favorites
# stores a digest: the cookie is the bearer credential, and this table must not
# be a second copy of it.
#
# The row's job today is revocation (eng review D2): delete it and that device
# is locked out even holding a validly signed cookie — without rotating
# secret_key_base, which would log out every web reader too. `last_seen_at` is
# touched at most once a day (guarded update_column, see ApplicationController).
# The push story adds its APNs column here later; this story deliberately
# does not.
class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :token_digest, null: false
      t.datetime :last_seen_at
      t.timestamps
      t.index :token_digest, unique: true
    end
  end
end
