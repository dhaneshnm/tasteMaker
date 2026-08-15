require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  test "note_seen writes once a day, not once a request" do
    device = Device.create!(token_digest: Digest::SHA256.hexdigest("uuid"))

    device.note_seen
    first = device.reload.last_seen_at
    assert first.present?

    device.note_seen
    assert_equal first, device.reload.last_seen_at,
      "a second sighting inside 24h must not write — SQLite pays per write"

    device.update_column(:last_seen_at, 25.hours.ago)
    device.note_seen
    assert device.reload.last_seen_at > first
  end

  test "note_seen does not churn updated_at" do
    device = Device.create!(token_digest: Digest::SHA256.hexdigest("uuid"))
    was = device.updated_at

    device.note_seen

    assert_equal was, device.reload.updated_at
  end
end
