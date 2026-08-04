class AllowDailyPickBlurbToBeBlank < ActiveRecord::Migration[8.1]
  # A day with no hand-written note runs the museum's own text instead
  # (decisions/0004). The model still refuses a day with neither.
  def change
    change_column_null :daily_picks, :blurb, true
  end
end
