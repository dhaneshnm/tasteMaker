require "test_helper"

# The exit door (story 0015): delete the account, delete its keeps, touch
# nothing that belongs to a device. The category's leader data-hostaged
# collections; this file is the promise that we cannot.
class AccountsTest < ActionDispatch::IntegrationTest
  test "deleting the account deletes the user and their keeps, and nothing else" do
    user = sign_in
    post "/collection/#{paintings(:sunflowers).id}"

    assert_difference "User.count" => -1, "Favorite.count" => -1 do
      delete "/account"
    end

    assert_equal 303, response.status
    assert_redirected_to root_path
    assert Favorite.exists?(collector_digest: favorites(:strangers_sunflowers).collector_digest),
      "a device's keep must survive somebody else's account deletion"
    refute User.exists?(user.id)

    # The session died with the account.
    get "/days"
    assert_equal 303, response.status
  end

  test "a device cannot delete anything here" do
    register_device

    assert_no_difference "User.count" do
      delete "/account"
    end
    assert_redirected_to root_path
  end

  test "two worlds never see each other's keeps" do
    register_device
    post "/collection/#{paintings(:sunflowers).id}"
    device_keep = Favorite.order(:created_at).last
    assert device_keep.collector_digest.present?

    sign_in
    get "/collection"

    assert_response :success
    refute_includes response.body, "1 work",
      "a signed-in reader must not inherit the device's collection"
  end
end
