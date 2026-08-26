class AddPushToDevicesAndDailyPicks < ActiveRecord::Migration[8.1]
  def change
    # Story 0010. Nil = not opted in. No index — the write path looks devices
    # up by the existing token_digest index; the daily send scan of a table
    # this size is nothing.
    add_column :devices, :apns_token, :string

    # The one-knock-per-day claim stamp (R1: the receipt lives in the schema,
    # the 0023 auto_tier lesson).
    add_column :daily_picks, :notified_at, :datetime

    # Stamped AFTER the send loop with how many pushes actually left. Claim-
    # before-send means notified_at alone audits "job claimed," not "pushes
    # sent" (eng review, outside voice #3) — this column is what tells the
    # two apart.
    add_column :daily_picks, :push_sent_count, :integer
  end
end
