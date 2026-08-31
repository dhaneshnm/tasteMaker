# Per-date tallies for the sit gate (story 0032, eng OV6): how many gates
# were shown, how many minutes ran to completion. Identifier-free by design —
# the beacon that feeds this carries no cookie and no reader key, so a row
# can never be joined back to a person.
class SitCounter < ApplicationRecord
  EVENTS = %w[shown completed].freeze

  # Race-safe increment: one SQL upsert, no read-modify-write window. Two
  # beacons landing together both count. The date is the server's day
  # (config.time_zone, America/New_York) — the same clock that rolls the
  # artwork over, so a tally row and a daily pick agree on what "today" was.
  def self.bump!(event)
    return unless EVENTS.include?(event)

    upsert(
      { date: Date.current, event => 1 },
      unique_by: :date,
      on_duplicate: Arel.sql("#{event} = #{event} + 1")
    )
  end
end
