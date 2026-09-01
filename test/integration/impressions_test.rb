require "test_helper"

# The impression frame's every answer (story 0033, replacing the sit gate).
# The load-bearing rule: `#control` is ANSWERED for everyone — an unmatched
# or bounced response would paint Turbo's "Content missing" (or the wall's
# sign-in link) into the calm page. The write is walled, user-only, and an
# upsert-or-delete: editable while the painting is today's pick, ink once
# the day passes.
class ImpressionsTest < ActionDispatch::IntegrationTest
  setup { @painting = paintings(:sunflowers) }

  # -- the read: one frame, every caller ------------------------------------

  test "a stranger gets the prompt and the quiet hint: no form, no link, no cookie" do
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "impression_#{@painting.id}"
    assert_includes response.body, daily_picks(:today).sit_prompt
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

  test "a signed-in reader with no line gets the composer, labelled by the prompt, no button" do
    sign_in
    get impression_control_path(@painting)

    assert_response :ok
    assert_includes response.body, "<form"
    assert_includes response.body, 'aria-labelledby="sit-prompt"'
    assert_includes response.body, 'maxlength="280"'
    assert_not_includes response.body, "<button",
      "autosave has no submit button — the whisper is the only acknowledgment"
  end

  test "a signed-in reader with a line gets the comment, not the composer" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "the jug leans")
    get impression_control_path(@painting)

    assert_includes response.body, "the jug leans"
    assert_not_includes response.body, "<form"
    assert_includes response.body, "cmt__edit",
      "today's own line is tap-to-edit"
    assert_not_includes response.body, daily_picks(:today).sit_prompt,
      "the prompt does not survive into the answered state"
  end

  test "?edit=1 returns today's own line to the composer, prefilled" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "half a thought")
    get impression_control_path(@painting, edit: "1")

    assert_includes response.body, "<form"
    assert_includes response.body, 'value="half a thought"'
  end

  test "on an archived painting the line is read-only, never tap-to-edit" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "the jug leans")
    get impression_control_path(@painting, view: "answer")

    assert_includes response.body, "the jug leans"
    assert_not_includes response.body, "<form"
    assert_not_includes response.body, "cmt__edit"
  end

  test "an archived painting with no line renders nothing — no hint, no prompt, no form" do
    sign_in
    get impression_control_path(@painting, view: "answer")

    assert_not_includes response.body, "<form"
    assert_not_includes response.body, "Sign in"
    assert_not_includes response.body, daily_picks(:today).sit_prompt
  end

  test "an archived request from a stranger renders nothing — no bounce, no nag" do
    get impression_control_path(@painting, view: "answer")

    assert_response :ok
    assert_not_includes response.body, "Sign in",
      "a hint on a page that never offered writing would be a nag"
  end

  # -- the write: walled, user-only, editable while today's pick -----------

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

  test "a second save is the line moving, not a second row" do
    user = sign_in
    post impression_path(@painting), params: { body: "first thought" }
    original_prompt = Impression.last.prompt

    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "second thought, better" }
    end
    assert_response :no_content
    assert_equal "second thought, better", user.impressions.last.body
    assert_equal original_prompt, user.impressions.last.prompt,
      "the prompt is stamped once — a later save never rewrites it"
  end

  test "a blank save over an existing line deletes it (eng OV2)" do
    user = sign_in
    user.impressions.create!(painting: @painting, body: "held")

    assert_difference("Impression.count", -1) do
      post impression_path(@painting), params: { body: "   " }
    end
    assert_response :no_content
    assert_not user.impressions.exists?(painting: @painting)
  end

  test "a blank save with nothing to delete is a harmless no-op" do
    sign_in
    assert_no_difference("Impression.count") do
      post impression_path(@painting), params: { body: "" }
    end
    assert_response :no_content
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
    get impression_control_path(@painting)

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;"
  end

  test "a junk painting id 404s at the routing layer" do
    get "/impression/not-a-painting/control"
    assert_response :not_found
  end
end
