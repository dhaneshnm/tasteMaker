require "test_helper"

# The device key's front desk (story 0015). An app secret guards it — the
# stated, accepted threat model is "stops open/anonymous access, not reverse
# engineering" (decisions/0011, Q3) — and the rate limit behind it must be
# demonstrably real, because the test environment's :null_store makes an
# un-pinned limiter pass every test while limiting nothing (eng review A1).
class DeviceRegistrationsTest < ActionDispatch::IntegrationTest
  test "no secret gets 401 and no cookie" do
    post "/device/registrations", params: { device_token: "uuid-1" }

    assert_response :unauthorized
    assert_nil cookies[:device].presence
    assert_equal 0, Device.count
  end

  test "a wrong secret gets 401" do
    post "/device/registrations", params: { device_token: "uuid-1" },
      headers: { "X-Tondo-App" => "wrong" }

    assert_response :unauthorized
  end

  # The precedence the whole suite now leans on. Both doors read credentials
  # first and ENV second, and on 2026-08-14 credentials gained the real values
  # while the helpers still typed ENV's — 149 tests 401'd, and a clone with no
  # master.key went on passing. If the order ever flips, this says so in one
  # line instead of a wall of unrelated red.
  test "both doors prefer credentials over ENV" do
    [ [ DeviceRegistrationsController.method(:expected_app_secret), %i[tondo app_secret], "TONDO_APP_SECRET" ],
      [ Admin::BaseController.method(:expected_password), %i[curator password], "CURATOR_PASSWORD" ] ].each do |expected, path, var|
      configured = Rails.application.credentials.dig(*path).presence || ENV[var]

      assert_equal configured, expected.call,
        "#{path.join(".")} and #{var} disagree about which one the door reads"
    end
  end

  test "the secret mints a device row and a signed permanent cookie" do
    post "/device/registrations", params: { device_token: "uuid-1" },
      headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }

    assert_response :no_content
    assert_equal 1, Device.count
    assert_equal Device.digest("uuid-1"), Device.first.token_digest,
      "the table stores the digest, never the token"
    assert cookies[:device].present?

    # The cookie is the key: the next request passes the wall.
    get "/days"
    assert_response :success
  end

  test "registration is idempotent — same UUID, one row" do
    2.times do
      post "/device/registrations", params: { device_token: "uuid-1" },
        headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }
      assert_response :no_content
    end

    assert_equal 1, Device.count
  end

  test "a CFNetwork-style user agent is accepted" do
    # The shell registers through URLSession, not a browser. allow_browser
    # judges user agents; this pins the endpoint open to the shell's
    # (eng review A4).
    post "/device/registrations", params: { device_token: "uuid-1" },
      headers: {
        "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret,
        "User-Agent" => "Tondo iOS/1 CFNetwork/1494.0.7 Darwin/23.4.0"
      }

    assert_response :no_content
  end

  test "the eleventh request in a minute is refused" do
    10.times do |i|
      post "/device/registrations", params: { device_token: "uuid-#{i}" },
        headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }
      assert_response :no_content
    end

    post "/device/registrations", params: { device_token: "uuid-11" },
      headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }

    assert_response :too_many_requests
  end

  test "a missing, nested, or absurd device_token is a 400, not a 500" do
    [ {}, { device_token: { a: "b" } }, { device_token: "x" * 4096 } ].each do |params|
      post "/device/registrations", params: params,
        headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }

      assert_response :bad_request, "#{params.inspect} did not 400"
    end
    assert_equal 0, Device.count
  end
end
