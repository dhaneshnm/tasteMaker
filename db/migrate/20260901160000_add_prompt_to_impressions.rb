class AddPromptToImpressions < ActiveRecord::Migration[8.0]
  def change
    # The looking prompt the reader answered under (story 0032 redesign,
    # 2026-09-01). Stamped server-side from the day's pick at save time —
    # which prompts produce the most writing is the seed-order data the
    # protocol planned to collect (user-research/0010).
    add_column :impressions, :prompt, :string, limit: 200
  end
end
