require "test_helper"

# The impression frame's every answer (story 0032). The load-bearing rule:
# `#control` is ANSWERED for everyone — an unmatched or bounced response
# would paint Turbo's "Content missing" (or the wall's sign-in link) into
# the cached front door. The write is walled and user-only.
class ImpressionsTest < ActionDispatch::IntegrationTest
  setup { @painting = paintings(:sunflowers) }

  # -- the read: one frame, four callers ------------------------------------

  test "a stranger gets an empty frame: no form, no link, no text, no cookie" do
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "impression_#{@painting.id}"
    assert_not_includes response.body, "<form"
    assert_not_includes response.body, "<a "
    assert_not_includes response.body, "Sign in"
    assert_nil response.headers["Set-Cookie"],
      "the anonymous null state must not mint a session"
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "a registered device gets the same nothing — the branch is current_user, not identified?" do
    register_device
    get impression_control_path(@painting)

    assert_response :ok
    assert_not_includes response.body, "<form"
  end

  test "a signed-in reader with no line gets the field, visibly labelled" do
    sign_in
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "<form"
    assert_includes response.body, "<label"
    assert_includes response.body, 'maxlength="280"'
  end

  test "a signed-in reader with a line gets the line and no field" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "the jug leans")
    get impression_control_path(@painting)

    assert_includes response.body, "the jug leans"
    assert_not_includes response.body, "<form"
  end

  test "a revealed-revisit fetch gets the line but never the field" do
    user = sign_in

    # No line yet: after reveal the writing moment is over — nothing renders.
    get impression_control_path(@painting, after: "reveal")
    assert_response :ok
    assert_not_includes response.body, "<form",
      "writing after reading is the order this story exists to prevent"

    # With a line: the juxtaposition survives the revisit.
    user.impressions.create!(painting: @painting, body: "kept line")
    get impression_control_path(@painting, after: "reveal")
    assert_includes response.body, "kept line"
    assert_not_includes response.body, "<form"
  end

  # -- the write: walled, user-only, ink ------------------------------------

  test "an anonymous write bounces off the wall" do
    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "drive-by" }
    end
    assert_response :redirect
  end

  test "a device write is refused — the field never rendered for it" do
    register_device
    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "no account" }
    end
    assert_response :forbidden
  end

  test "a signed-in write lands, stripped, and renders the line" do
    sign_in
    assert_difference("Impression.count", 1) do
      post impression_path(@painting), params: { body: "  a hum of yellow  " }
    end
    assert_response :ok
    assert_includes response.body, "a hum of yellow"
    assert_not_includes response.body, "<form"
  end

  test "a blank line is refused with the reader-facing error, and nothing saves" do
    sign_in
    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "   " }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "sit__error"
    assert_includes response.body, "<form", "the field must survive its own failure"
  end

  test "281 characters is refused and the reader's text stays in the field" do
    sign_in
    post impression_path(@painting), params: { body: "b" * 281 }
    assert_response :unprocessable_entity
    assert_includes response.body, "b" * 281
  end

  test "a second line for the same painting is refused — write-once" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "first and only")
    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "second thoughts" }
    end
    assert_response :unprocessable_entity
  end

  test "yesterday's painting still accepts a line — the rollover must not eat a sit" do
    sign_in
    post impression_path(paintings(:harbour)), params: { body: "wet grey, open air" }
    assert_response :ok
  end

  test "a line is rendered as text, never as markup" do
    sign_in
    post impression_path(@painting), params: { body: "<script>alert(1)</script>" }
    assert_response :ok
    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;"
  end

  test "a junk painting id 404s at the routing layer" do
    get "/impression/not-a-painting/control"
    assert_response :not_found
  end
end
