require "test_helper"

# The push opt-in's front desk (story 0010). Two doors, two auth models:
# POST is native (NativeEndpoint-gated, mirrors device_registrations_test.rb);
# DELETE is a walled web Turbo form (mirrors devices_controller's idiom).
class PushRegistrationsTest < ActionDispatch::IntegrationTest
  test "no secret gets 401 and sets nothing" do
    post "/device/push_registrations",
      params: { device_token: "uuid-1", mode: "enroll", apns_token: "a" * 64 }

    assert_response :unauthorized
    assert_equal 0, Device.count
  end

  test "a wrong secret gets 401" do
    post "/device/push_registrations",
      params: { device_token: "uuid-1", mode: "enroll", apns_token: "a" * 64 },
      headers: { "X-Tondo-App" => "wrong" }

    assert_response :unauthorized
  end

  test "enroll on a digest with no Device row finds-or-creates it" do
    register_push(mode: "enroll", apns_token: "a" * 64)

    assert_response :no_content
    device = Device.find_by(token_digest: Device.digest("test-device-uuid"))
    assert device, "enroll must create the row, not merely 401/404 on a stranger"
    assert_equal "a" * 64, device.apns_token
  end

  test "enroll is idempotent — same digest, one row, token set either way" do
    2.times { register_push(mode: "enroll", apns_token: "a" * 64) }

    assert_response :no_content
    assert_equal 1, Device.count
  end

  # The single most load-bearing test in this story (eng review, outside
  # voice #1): launch healing must never silently re-enroll a web opt-out.
  test "refresh on a device with no apns_token stays opted out" do
    register_device
    device = Device.find_by(token_digest: Device.digest("test-device-uuid"))
    assert_nil device.apns_token, "the fixture setup itself must start opted out"

    register_push(mode: "refresh", apns_token: "b" * 64)

    assert_response :no_content
    assert_nil device.reload.apns_token,
      "refresh must not enroll a device that was never opted in — that is a silent opt-out reversal"
  end

  test "refresh on an already-opted-in device rotates the token" do
    register_push(mode: "enroll", apns_token: "a" * 64)

    register_push(mode: "refresh", apns_token: "b" * 64)

    assert_response :no_content
    assert_equal "b" * 64, Device.find_by(token_digest: Device.digest("test-device-uuid")).apns_token
  end

  test "refresh with enabled=false clears the token" do
    register_push(mode: "enroll", apns_token: "a" * 64)

    register_push(mode: "refresh", apns_token: nil, enabled: false)

    assert_response :no_content
    assert_nil Device.find_by(token_digest: Device.digest("test-device-uuid")).apns_token
  end

  test "refresh on a digest with no Device row at all is a harmless no-op" do
    register_push(mode: "refresh", apns_token: "a" * 64)

    assert_response :no_content
    assert_equal 0, Device.count
  end

  test "an unknown mode is a 400" do
    register_push(mode: "delete-everything", apns_token: "a" * 64)

    assert_response :bad_request
  end

  test "a junk apns_token is a 400, not a 500" do
    [ "not-hex-!!!", "x" * 4096, "" ].each do |bad_token|
      register_push(mode: "enroll", apns_token: bad_token)
      assert_response :bad_request, "#{bad_token.inspect[0, 40]} did not 400"
    end
  end

  test "the eleventh request in a minute is refused, with the pinned store" do
    10.times { |i| register_push(device_token: "uuid-#{i}", mode: "enroll", apns_token: "a" * 64) }
    register_push(device_token: "uuid-11", mode: "enroll", apns_token: "a" * 64)

    assert_response :too_many_requests
  end

  # ---- DELETE — the web door -----------------------------------------------

  test "delete clears the opted-in device's token" do
    register_device
    register_push(mode: "enroll", apns_token: "a" * 64)

    delete "/device/push_registration"

    assert_response :no_content
    assert_nil Device.find_by(token_digest: Device.digest("test-device-uuid")).apns_token
  end

  test "delete without a device cookie bounces off the wall" do
    delete "/device/push_registration"

    assert_response :see_other
  end

  # Eng review, outside voice #6: a device wipe re-mints the Keychain UUID
  # and can leave a stale second Device row holding the same apns_token.
  # Row-scoped opt-out would leave that row still knocking the phone.
  test "delete clears every row holding the same token, not just this device's" do
    register_push(device_token: "uuid-old", mode: "enroll", apns_token: "shared" + "a" * 58)
    register_device(token: "uuid-new")
    register_push(device_token: "uuid-new", mode: "enroll", apns_token: "shared" + "a" * 58)

    delete "/device/push_registration"

    assert_response :no_content
    assert Device.where.not(apns_token: nil).none?,
      "the stale row must be cleared too, or the wiped device keeps getting knocked"
  end

  test "delete when nothing is opted in is a harmless no-op" do
    register_device

    delete "/device/push_registration"

    assert_response :no_content
  end
end
