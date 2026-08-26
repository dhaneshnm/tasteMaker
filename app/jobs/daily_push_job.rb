# The noon knock (story 0010). Runs daily via config/recurring.yml, seven
# hours after FillQueueJob's 05:00 ET fill guarantees the day exists.
#
#   perform
#     │
#     ├─ today published? ──────────────────────── no → abort, nothing claimed
#     │
#     ├─ claim notified_at (atomic UPDATE) ───────── lost the race → abort
#     │                                              (another run already
#     │                                               claimed it — Solid
#     │                                               Queue is enqueue-once,
#     │                                               not run-once)
#     │
#     ├─ Apnotic::Connection (token auth; connect timeout + ensure close)
#     │    └─ for each DISTINCT opted-in token:
#     │         ├─ 200            → sent += 1
#     │         ├─ 410 Unregistered / 400 BadDeviceToken → prune that token
#     │         └─ anything else   → keep going, one bad token must not
#     │                              starve the rest
#     │    rescue (connection-level) → one Sentry event, sent stays at
#     │                                 whatever already landed, no hung
#     │                                 Puma-embedded worker thread
#     │
#     └─ stamp push_sent_count = sent ── the claimed-vs-delivered receipt
#        (decisions/0019 amendment): `notified_at` alone can't be the
#        tripwire — a revoked .p8 would stamp every day and send nothing,
#        gap-free. This column is what /queue-health actually has no need
#        to read (a legitimate zero-device day looks the same as a broken
#        one on THIS column alone) but a human auditing the table does.
#
# Claim-then-send is at-most-once BY CHOICE (decisions/0019): a process
# death mid-send means some devices miss a day — accepted; two knocks is
# the notification-spam pattern this story exists to not be.
class DailyPushJob < ApplicationJob
  queue_as :default

  # The shell's own bundle id (PRODUCT_BUNDLE_IDENTIFIER, Config/Shared.xcconfig).
  # Not a secret — just coupled to the iOS project — so it is named here
  # rather than threaded through credentials.
  APNS_TOPIC = "com.dhaneshnm.tondo"

  # Bounds BOTH the initial handshake (Apnotic::Connection's connect_timeout)
  # and each individual push (the timeout: option on Connection#push). The
  # default connect_timeout is 30s and there is no default push timeout at
  # all — inside a Puma-embedded Solid Queue worker, an unbounded stall on a
  # day already claimed is a silent missed knock (eng review finding 1).
  CONNECTION_TIMEOUT = 10

  # OWNER COPY NEEDED (build flow step 7) — real notification copy blocks
  # ship, not implementation. %{title} and %{artist} are the painting's.
  PUSH_TITLE = "[OWNER COPY] Today's Tondo"
  PUSH_BODY_TEMPLATE = "[OWNER COPY] %{title}, %{artist}"

  # The test seam (plan step 8): a fake recording connection swapped in here
  # need only answer #push and #close. Nil in production, so the real
  # Apnotic::Connection is built lazily — only when there is at least one
  # opted-in token to send to, and never merely by requiring this file.
  class << self
    attr_accessor :connection_override
  end

  def perform
    pick = DailyPick.current
    return unless pick&.scheduled_on == Date.current

    claimed = DailyPick.where(id: pick.id, notified_at: nil)
                        .update_all(notified_at: Time.current)
    return if claimed.zero?

    sent = send_to_devices(pick)
    pick.update_column(:push_sent_count, sent)
  end

  private
    def send_to_devices(pick)
      tokens = Device.where.not(apns_token: nil).distinct.pluck(:apns_token)
      return 0 if tokens.empty?

      sent = 0
      connection = build_connection

      begin
        tokens.each do |token|
          response = connection.push(build_notification(pick, token), timeout: CONNECTION_TIMEOUT)
          sent += handle_response(response, token)
        end
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { sent: sent, total: tokens.size })
      ensure
        connection&.close
      end

      sent
    end

    def handle_response(response, token)
      return 0 if response.nil?
      return 1 if response.ok?

      if %w[410 400].include?(response.status) &&
         %w[Unregistered BadDeviceToken].include?(response.body.is_a?(Hash) ? response.body["reason"] : nil)
        Device.where(apns_token: token).update_all(apns_token: nil)
      end

      0
    end

    def build_connection
      self.class.connection_override || Apnotic::Connection.new(
        url: Rails.env.production? ? Apnotic::APPLE_PRODUCTION_SERVER_URL : Apnotic::APPLE_DEVELOPMENT_SERVER_URL,
        auth_method: :token,
        cert_path: StringIO.new(credentials.fetch(:private_key)),
        key_id: credentials.fetch(:key_id),
        team_id: credentials.fetch(:team_id),
        connect_timeout: CONNECTION_TIMEOUT
      )
    end

    def credentials
      Rails.application.credentials.dig(:apns) || {}
    end

    def build_notification(pick, token)
      notification = Apnotic::Notification.new(token)
      notification.alert = {
        "title" => PUSH_TITLE,
        "body" => format(PUSH_BODY_TEMPLATE, title: pick.painting.title, artist: pick.painting.artist_display)
      }
      notification.topic = APNS_TOPIC
      notification.push_type = "alert"
      notification.priority = 10
      notification
    end
end
