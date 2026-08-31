class CreateSitCounters < ActiveRecord::Migration[8.0]
  def change
    # The gate's only receipt (story 0032, eng OV6). Two integers per date,
    # no identity, no cookie — the ≥20%-completed success signal reads
    # completed/shown off these rows. A table rather than a log line for the
    # same reason 0023 chose `auto_tier`: Kamal replaces the container on
    # every deploy, and the kill review reads receipts that survive that.
    create_table :sit_counters do |t|
      t.date :date, null: false
      t.integer :shown, null: false, default: 0
      t.integer :completed, null: false, default: 0
      t.timestamps
    end
    add_index :sit_counters, :date, unique: true
  end
end
