require "test_helper"

# The exit door for the identity that had none (story 0016).
#
# `AccountsController#destroy` returns early `unless current_user`, so before
# `DELETE /device` existed the DEFAULT state of the iOS shell — a registered
# device whose reader never signed in — could not delete its row or the works it
# had kept. `/privacy` promises in-app deletion. That promise was false for the
# majority of readers, and this file is what keeps it true.
class DevicesTest < ActionDispatch::IntegrationTest
  test "a registered device deletes its row" do
    token = register_device
    digest = Device.digest(token)
    assert Device.exists?(token_digest: digest)

    delete device_path
    assert_redirected_to root_path
    assert_not Device.exists?(token_digest: digest), "the device row survived its own delete"
  end

  test "the works kept on that device go with it" do
    token = register_device
    painting = paintings(:harbour)
    post "/collection/#{painting.id}"
    assert_equal 1, Favorite.collected_by(Device.digest(token)).count

    delete device_path

    assert_equal 0, Favorite.collected_by(Device.digest(token)).count,
      "favorites are keyed by digest with no dependent: :destroy — deleting the " \
      "Device row alone orphans them and the policy's deletion promise is false"
  end

  test "the cookie goes too, so a deleted reader is not locked out" do
    register_device
    delete device_path

    # Left in place, the cookie names a digest with no Device behind it:
    # `current_device` returns nil, the wall bounces every request to
    # `/#signin`, and the reader who just deleted their data is locked out of a
    # product that is free and asks for nothing. They should land on the public
    # landing page, which is where an identityless visitor belongs.
    assert cookies[:device].blank?, "the device cookie outlived the device row"

    get root_path
    assert_response :success
  end

  test "another device's keeps are untouched" do
    mine = register_device
    painting = paintings(:harbour)
    post "/collection/#{painting.id}"

    theirs = open_session
    other_token = register_device(token: "a-second-device", session: theirs)
    theirs.post "/collection/#{painting.id}"
    assert_equal 1, Favorite.collected_by(Device.digest(other_token)).count

    delete device_path

    assert_equal 0, Favorite.collected_by(Device.digest(mine)).count
    assert_equal 1, Favorite.collected_by(Device.digest(other_token)).count,
      "deleting one device took another device's collection with it"
  end

  test "a signed-in reader is redirected, not deleted" do
    register_device
    token_digest = Device.digest("test-device-uuid")
    sign_in

    delete device_path
    assert_redirected_to root_path

    # An account holder has their own door (`DELETE /account`). Deleting the
    # device out from under a signed-in session would strand a reader whose
    # keeps live somewhere else entirely.
    assert Device.exists?(token_digest: token_digest),
      "a signed-in reader's device row was destroyed by the device door"
  end

  test "the collection page offers each identity its own door" do
    register_device
    get collection_path
    assert_select "form[action=?]", device_path
    assert_select "form[action=?]", account_path, count: 0

    sign_in
    get collection_path
    assert_select "form[action=?]", account_path
    assert_select "form[action=?]", device_path, count: 0
  end
end
