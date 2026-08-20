class AddAutoTierToDailyPicks < ActiveRecord::Migration[8.1]
  def change
    add_column :daily_picks, :auto_tier, :integer
  end
end
