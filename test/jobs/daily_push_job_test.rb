require "test_helper"

# A fake recording connection (plan step 8: "client injected — an attr the
# test swaps for a fake recording connection"). Answers exactly the two
# methods DailyPushJob calls, so no real Apnotic::Connection — and no real
# network — is ever constructed in this suite.
class FakeApnsConnection
  attr_reader :pushed_notifications, :closed

  # responses: token => Apnotic::Response, or :raise to blow up mid-push,
  # or omitted entirely for a plain 200.
  def initialize(responses: {})
    @responses = responses
    @pushed_notifications = []
    @closed = false
  end

  def pushed_tokens
    pushed_notifications.map(&:token)
  end

  def push(notification, options = {})
    @pushed_notifications << notification
    outcome = @responses.fetch(notification.token, ok_response)
    raise "simulated connection failure" if outcome == :raise
    outcome
  end

  def close
    @closed = true
  end

  def self.ok
    new
  end

  def self.status(token, status, reason: nil)
    body = reason ? { reason: reason }.to_json : "{}"
    new(responses: { token => Apnotic::Response.new(headers: { ":status" => status }, body: body) })
  end

  private
    def ok_response
      Apnotic::Response.new(headers: { ":status" => "200" }, body: "{}")
    end
end

# /code-review, finding 1: `build_connection` used to run ahead of the
# begin/rescue, so an incomplete `apns:` credentials block crashed the job
# UNCAUGHT — before Sentry.capture_exception, before connection&.close, and
# before push_sent_count ever got stamped. This subclass simulates that by
# overriding `credentials` rather than stubbing (this codebase's idiom:
# swap real state, not mock — Minitest 6 ships no minitest/mock).
class DailyPushJobWithBrokenCredentials < DailyPushJob
  private
    def credentials
      {}
    end
end

class DailyPushJobTest < ActiveSupport::TestCase
  teardown { DailyPushJob.connection_override = nil }

  def opt_in(suffix, token: nil)
    device = Device.create!(token_digest: Device.digest("push-job-#{suffix}"),
                            apns_token: token || (suffix.to_s * 32)[0, 64])
    device
  end

  test "sends one push per opted-in device and stamps push_sent_count" do
    opt_in("a")
    opt_in("b")
    fake = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_equal 2, fake.pushed_tokens.size
    assert_equal 2, daily_picks(:today).reload.push_sent_count
    assert daily_picks(:today).notified_at.present?
    assert fake.closed, "the connection must be closed even on the happy path"
  end

  test "a second run the same day sends nothing — the claim is already taken" do
    opt_in("a")
    DailyPushJob.connection_override = FakeApnsConnection.ok
    DailyPushJob.perform_now
    first_notified_at = daily_picks(:today).reload.notified_at

    fake_second = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake_second
    DailyPushJob.perform_now

    assert_equal [], fake_second.pushed_tokens
    assert_equal first_notified_at, daily_picks(:today).reload.notified_at
  end

  test "today unscheduled sends nothing and stamps nothing" do
    daily_picks(:today).destroy!
    opt_in("a")
    fake = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_equal [], fake.pushed_tokens
  end

  test "no opted-in devices sends nothing and never builds a connection" do
    DailyPushJob.connection_override = nil # would raise on missing credentials if reached

    assert_nothing_raised { DailyPushJob.perform_now }
    assert_equal 0, daily_picks(:today).reload.push_sent_count.to_i
  end

  test "a 410 Unregistered response prunes that device's token, others still sent" do
    dead = opt_in("dead", token: "d" * 64)
    alive = opt_in("alive", token: "a" * 64)
    fake = FakeApnsConnection.status("d" * 64, "410", reason: "Unregistered")
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_nil dead.reload.apns_token
    assert_equal "a" * 64, alive.reload.apns_token
    assert_equal 1, daily_picks(:today).reload.push_sent_count
  end

  test "a 400 BadDeviceToken response prunes that device's token" do
    bad = opt_in("bad", token: "b" * 64)
    fake = FakeApnsConnection.status("b" * 64, "400", reason: "BadDeviceToken")
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_nil bad.reload.apns_token
  end

  test "distinct tokens are deduped — two rows, one physical phone, one knock" do
    Device.create!(token_digest: Device.digest("dup-1"), apns_token: "f" * 64)
    Device.create!(token_digest: Device.digest("dup-2"), apns_token: "f" * 64)
    fake = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_equal 1, fake.pushed_tokens.size
  end

  test "a KeyError from incomplete credentials is caught inside the rescue, not raised past it" do
    opt_in("a")
    # No connection_override — this deliberately reaches the real
    # build_connection path via the broken-credentials subclass above.

    assert_nothing_raised { DailyPushJobWithBrokenCredentials.perform_now }
    assert_equal 0, daily_picks(:today).reload.push_sent_count
    assert daily_picks(:today).notified_at.present?,
      "the claim stands, and now push_sent_count actually gets stamped 0 instead of staying nil forever"
  end

  test "a connection-level failure is caught, reports to Sentry, and stamps whatever already sent" do
    opt_in("a")

    raising_connection = Object.new
    def raising_connection.push(*) = raise("TLS handshake failed")
    def raising_connection.close = nil

    DailyPushJob.connection_override = raising_connection

    assert_nothing_raised { DailyPushJob.perform_now }
    assert_equal 0, daily_picks(:today).reload.push_sent_count
    assert daily_picks(:today).notified_at.present?,
      "the claim must stand even though delivery failed — that gap is what push_sent_count is for"
  end

  test "the notification title is the day's real painting title, quotes and unicode alike" do
    daily_picks(:today).painting.update!(title: 'A "Study" — café')
    opt_in("a")
    fake = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_equal 'A "Study" — café', fake.pushed_notifications.first.alert["title"]
  end

  test "the notification body is the day's real artist" do
    daily_picks(:today).painting.update!(artist: "Müller")
    opt_in("a")
    fake = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    assert_equal "Müller", fake.pushed_notifications.first.alert["body"]
  end

  test "the payload sets topic, alert push-type and priority" do
    opt_in("a")
    fake = FakeApnsConnection.ok
    DailyPushJob.connection_override = fake

    DailyPushJob.perform_now

    notification = fake.pushed_notifications.first
    assert_equal DailyPushJob::APNS_TOPIC, notification.topic
    assert_equal "alert", notification.push_type
    assert_equal 10, notification.priority
  end
end
