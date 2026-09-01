require "test_helper"

# The forcing function for story 0007, narrowed by story 0015.
#
# `/` is `Cache-Control: public`, and production runs behind Thruster's HTTP
# cache (Dockerfile, 64MB, enabled by default with no config file). A `public`
# response that also carries a `Set-Cookie` is a shared cache holding one
# reader's session together with the masked CSRF token baked into the same body
# — replay them together and visitor B is visitor A.
#
# Story 0015 put `/days` and `/feed` behind the wall and made them `private`
# (wall_test holds that side), which left the front door as the only public page
# — and made it matter more, not less: it is the one page every visitor state
# shares, byte-identical, with all the personal machinery behind its two private
# fragments (keep, sign-in).
#
# Story 0016 added two more, and this comment used to say the front door was the
# ONLY one. `/privacy` and `/support` are reachable without an identity by
# requirement rather than by choice: App Store Connect will not accept the record
# without them, and Apple fetches both with no account.
#
# Precise about which "public" this file means, because the two are easy to
# conflate. These pages are publicly REACHABLE (no wall) but not publicly
# CACHEABLE — measured in production they answer `Cache-Control: max-age=0,
# private, must-revalidate`, Rails' default, which is the conservative side of
# the risk this file exists to guard. The danger is a `public` response carrying
# a `Set-Cookie`; these carry neither.
#
# They are listed here anyway, and that is the point: their `PagesController`
# deliberately inherits `ActionController::Base` rather than
# `ApplicationController`, so it gets NONE of the shared guards for free. A
# future `expires_in ..., public: true` on a legal page would be one line, would
# look harmless, and nothing else in the suite would notice.
class PublicCacheHeadersTest < ActionDispatch::IntegrationTest
  PUBLIC_PAGES = %w[/ /privacy /support].freeze

  # Forgery protection goes on for the whole file, not per test.
  #
  # The suite disables it, and `csrf_meta_tags` returns nil when it is off
  # without ever calling `form_authenticity_token`. So a test written here
  # without it would pass against the OLD layout too, proving nothing. This
  # file's entire subject is CSRF and session behaviour, so making that
  # impossible to forget beats remembering it once per test.
  with_forgery_protection!

  test "no public page sets a cookie" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_response :success, "#{path} did not render"
      assert_nil response.headers["Set-Cookie"],
        "#{path} set a cookie: #{response.headers["Set-Cookie"]}"
    end
  end

  test "no public page renders a CSRF meta tag" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_select "meta[name=?]", "csrf-token", count: 0,
        message: "#{path} rendered a CSRF meta tag, which is what writes the session"
    end
  end

  # The general form of the rule, and the one that survives refactoring.
  #
  # A form is the other way a page writes the session: `form_with` and
  # `button_to` both emit `form_authenticity_token`, which writes
  # `session[:_csrf_token]`, which emits `Set-Cookie` — on a response a shared
  # cache is allowed to store and replay.
  #
  # Story 0015 raises the stakes: the sign-in fragment's buttons are exactly
  # such forms, and they must arrive ONLY through the private `signin` frame —
  # the cached page carries the empty frame and none of the machinery, the
  # same split the keep control made in story 0014.
  test "no public page contains a form at all" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_select "form", count: 0,
        message: "#{path} rendered a form, which writes the session on a cached page"
    end
  end

  # Story 0018. `/` gained a per-page local (`link: chrome != :front_door` in
  # `shared/_artist_line`) so the artist name renders dim instead of linking
  # to a walled page (eng review X3/X11). A local branching on *chrome*, not
  # on *who is asking*, must render the identical body for every reader —
  # the whole point of keeping `/` byte-identical behind a shared cache.
  test "the front door renders byte-identical markup for a cookieless visitor and a registered device" do
    get "/"
    cookieless_body = response.body

    register_device
    get "/"

    assert_equal cookieless_body, response.body,
      "/ rendered different markup for a cookieless visitor than for a registered device"
  end

  # Story 0031. The share button's reveal is deliberately NOT this kind of
  # branch — it happens entirely client-side, on `navigator.userAgent`, so
  # that `/` never has to know who is asking. This test is the server-side
  # half of that promise: a request carrying the exact User-Agent a 1.2 shell
  # sends gets the SAME bytes back as a plain browser. A future change that
  # tried to grow the share button server-side from the request's UA (the
  # more "obvious" way to build this) would poison the shared cache exactly
  # like a per-visitor keep frame would, and this is the test that catches it.
  test "the front door renders byte-identical markup for a shell User-Agent and a plain browser" do
    get "/"
    browser_body = response.body

    get "/", headers: { "HTTP_USER_AGENT" => "Tondo iOS/1.2 Hotwire Native iOS; Turbo Native iOS; bridge-components: [share]" }

    assert_equal browser_body, response.body,
      "/ rendered different markup for a shell User-Agent than for a plain browser"
  end

  # The cookie is the defect; the caching is deliberate and must survive the fix.
  test "the front door stays publicly cacheable and still revalidates" do
    get "/"

    assert_equal "public, no-cache", response.headers["Cache-Control"], "/ lost its caching"
    etag = response.headers["ETag"]
    assert etag.present?, "/ has no ETag to revalidate against"

    get "/", headers: { "HTTP_IF_NONE_MATCH" => etag }

    assert_response :not_modified, "/ stopped returning 304 on revalidation"
  end

  # Story 0033. The conversation thread lives INSIDE the cached public page,
  # so its markup must be identical for everyone: the thread open, the pin
  # folded, one inert frame with no src (no per-visitor fetch is even named
  # until `sit_controller` connects), and none of the personal machinery —
  # the impression form, AND the prompt that labels it, arrive only through
  # the walled fragment (DR6: the prompt moved inside the frame precisely so
  # it could be absent from the answered branch without a client-side
  # deletion — see `impressions_test.rb` for the prompt actually appearing).
  # The byte-identical tests above hold the "same for every visitor state"
  # half; this holds the shape.
  test "the front door ships the thread open, the pin folded, the frame inert" do
    get "/"

    assert_includes response.body, 'class="conv"',
      "the thread is not on the cached page"
    assert_not_includes response.body, '<details class="cmt__pin" open',
      "the cached page must never ship the pin pre-opened"
    frame = response.body[/<turbo-frame[^>]*id="impression_\d+"[^>]*>/]
    assert frame.present?, "the impression frame is missing from the thread"
    assert_not_includes frame, "src=",
      "the inert frame must not carry a src — sit_controller assigns it"
    assert_not_includes response.body, daily_picks(:today).sit_prompt,
      "the prompt lives inside the frame now, never the cached page (DR6)"
    assert_not_includes response.body, "sit__input",
      "the field belongs to the walled fragment, never the cached page"
  end

  # The pin's describedby swap (eng OV5, carried from 0032): while folded,
  # the artwork is described by the day's prompt — never the note, which
  # aria-describedby would flatten into the accessible name even though it
  # is hidden.
  test "the folded artwork is described by the prompt, not the note" do
    get "/"

    img = response.body[/<img[^>]*class="plate__img"[^>]*>/]
    assert_includes img, 'aria-describedby="sit-prompt"'
  end
end
