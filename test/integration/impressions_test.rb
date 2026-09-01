require "test_helper"

# The impression frame's every answer (story 0032, redesigned 2026-09-01).
# The load-bearing rule: `#control` is ANSWERED for everyone — an unmatched
# or bounced response would paint Turbo's "Content missing" (or the wall's
# sign-in link) into the cached front door. The write is walled, user-only,
# and an autosave upsert: a draft until the reveal.
class ImpressionsTest < ActionDispatch::IntegrationTest
  setup { @painting = paintings(:sunflowers) }

  # -- the read: one frame, every caller ------------------------------------

  test "a stranger gets the quiet hint: no form, no link, no cookie" do
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "impression_#{@painting.id}"
    assert_includes response.body, "Sign in to keep your answer."
    assert_not_includes response.body, "<form"
    assert_not_includes response.body, "<a "
    assert_nil response.headers["Set-Cookie"],
      "the anonymous null state must not mint a session"
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "a registered device gets the hint too — the branch is current_user, not identified?" do
    register_device
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "Sign in to keep your answer."
    assert_not_includes response.body, "<form"
  end

  test "a signed-in reader gets the field, labelled by the prompt, no button" do
    sign_in
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "<form"
    assert_includes response.body, 'aria-labelledby="sit-prompt"'
    assert_includes response.body, 'maxlength="280"'
    assert_not_includes response.body, "<button",
      "autosave has no button — the whisper is the only acknowledgment"
  end

  test "the field returns prefilled while the answer is still a draft" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "half a thought")
    get impression_control_path(@painting)

    assert_includes response.body, 'value="half a thought"'
    assert_includes response.body, "<form"
  end

  test "after the reveal the answer is ink: read-only line, no field" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "the jug leans")
    get impression_control_path(@painting, after: "reveal")

    assert_includes response.body, "the jug leans"
    assert_not_includes response.body, "<form"
  end

  test "after the reveal with nothing written there is nothing — no field, no hint" do
    sign_in
    get impression_control_path(@painting, after: "reveal")
    assert_not_includes response.body, "<form"
    assert_not_includes response.body, "Sign in"

    delete "/session"
    get impression_control_path(@painting, after: "reveal")
    assert_response :ok
    assert_not_includes response.body, "Sign in",
      "a hint under an open note is a nag"
  end

  # -- the write: walled, user-only, a draft until the reveal ----------------

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

  test "the first save lands stripped, with the day's prompt stamped on" do
    sign_in
    assert_difference("Impression.count", 1) do
      post impression_path(@painting), params: { body: "  a hum of yellow  " }
    end
    assert_response :no_content

    impression = Impression.last
    assert_equal "a hum of yellow", impression.body
    assert_equal daily_picks(:today).sit_prompt, impression.prompt
  end

  test "a second save is the draft moving, not a second row" do
    user = sign_in
    post impression_path(@painting), params: { body: "first thought" }
    original_prompt = Impression.last.prompt

    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "second thought, better" }
    end
    assert_response :no_content
    assert_equal "second thought, better", user.impressions.last.body
    assert_equal original_prompt, user.impressions.last.prompt,
      "the prompt is stamped once — a later autosave never rewrites it"
  end

  test "a blank save is refused and moves nothing" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "held")
    post impression_path(@painting), params: { body: "   " }
    assert_response :unprocessable_entity
    assert_equal "held", user.impressions.last.body
  end

  test "281 characters is one too many" do
    sign_in
    post impression_path(@painting), params: { body: "b" * 281 }
    assert_response :unprocessable_entity
    assert_equal 0, Impression.count
  end

  test "yesterday's painting still accepts a line, under yesterday's prompt" do
    sign_in
    post impression_path(paintings(:harbour)), params: { body: "wet grey, open air" }
    assert_response :no_content
    assert_equal daily_picks(:yesterday).sit_prompt, Impression.last.prompt
  end

  test "an answer renders as text, never as markup" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "<script>alert(1)</script>")
    get impression_control_path(@painting, after: "reveal")

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;"
  end

  test "a junk painting id 404s at the routing layer" do
    get "/impression/not-a-painting/control"
    assert_response :not_found
  end
end
