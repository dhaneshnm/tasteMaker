# The account key (story 0015). A user is an OAuth subject and nothing else:
# provider + uid is the identity, email and name are display data Apple only
# sends once. No password column will ever join them (decisions/0011).
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.string :name
      t.timestamps
      t.index [ :provider, :uid ], unique: true
    end
  end
end
