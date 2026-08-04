class AllowDailyPickBlurbToBeBlank < ActiveRecord::Migration[8.1]
  # A day with no hand-written note runs the museum's own text instead
  # (decisions/0004). The model still refuses a day with neither.
  def up
    change_column_null :daily_picks, :blurb, true
  end

  # Not reversible once the feature has been used: re-adding NOT NULL fails on
  # every day that is running museum text, and the only way to satisfy it would
  # be to copy borrowed words into the curator's own column — which is the one
  # thing this design exists to avoid. Write the notes, or drop the rows.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
