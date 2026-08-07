require "test_helper"

# The forcing function for story 0009.
#
# The fix itself is three deleted lines in `_head.html.erb`, which is exactly the
# kind of fix somebody undoes in six weeks by pasting the Google embed snippet
# back in. The files below are the only thing standing between that paste and
# production.
#
# The assertion is deliberately wider than "no font CDN". What the story is
# actually protecting is a property of the whole `<head>`: on a cold load this
# app talks to nobody but itself. A tag manager, an icon CDN or a hosted
# stylesheet would each break that just as thoroughly as a font host, and story
# 0008 raises the stakes — a native shell's error screen exists for the case
# where there is no network at all, so anything it cannot fetch it does not have.
class SelfHostedFontsTest < ActionDispatch::IntegrationTest
  # The 404 is a rendered screen (story 0004), so it has a `<head>` too, and it
  # is the one screen most likely to be seen on a bad connection.
  with_rescued_exceptions!

  READER_PAGES = %w[/ /days /feed /nope].freeze

  FONT_HOSTS = %w[fonts.googleapis.com fonts.gstatic.com].freeze

  # `<link href>` and `<script src>` are the render-blocking, IP-leaking
  # positions. `<img>` and `<a>` are not: artwork images are Active Storage on
  # local disk, and a museum credit link is a place a reader chooses to go.
  SUBRESOURCE = "link[href], script[src]".freeze

  test "no reader-facing page names a third-party font host" do
    READER_PAGES.each do |path|
      get path

      FONT_HOSTS.each do |host|
        assert_not_includes response.body, host,
          "#{path} reached out to #{host} — the fonts are supposed to come from us"
      end
    end
  end

  test "the curator's desk does not name one either" do
    get admin_daily_picks_path, headers: curator_headers

    assert_response :success
    FONT_HOSTS.each do |host|
      assert_not_includes response.body, host, "the admin layout reached out to #{host}"
    end
  end

  # The general form, and the one that survives someone adding a different CDN.
  test "no reader-facing page loads a subresource from any other host" do
    READER_PAGES.each do |path|
      get path

      css_select(SUBRESOURCE).each do |node|
        url = node["href"] || node["src"]
        next if url.blank? || url.start_with?("data:")

        assert_no_match %r{\A(?:https?:)?//}, url,
          "#{path} loads #{url} from another host; a cold load must talk to nobody but us"
      end
    end
  end

  # The other half of the story: the fonts have to actually be there. Without
  # this, deleting the `@font-face` block would pass every assertion above while
  # dropping the whole product into Georgia.
  #
  # Twelve faces — two families x roman/italic x latin/latin-ext/vietnamese.
  # The count is asserted because losing latin-ext silently is the failure mode
  # that matters: it only shows up on the artist names that carry ā, č, ō, ū, ž
  # or ȟ, which is precisely the curation the Better bucket asks for and the
  # least likely thing to be caught by eye on the daily page.
  test "the stylesheet serves twelve woff2 faces from this app" do
    get "/"
    href = css_select("link[rel=stylesheet]").first["href"]

    get href

    assert_response :success
    faces = response.body.scan(/url\(["']?([^"')]+\.woff2)["']?\)/).flatten

    assert_equal 12, faces.size, "expected 12 @font-face sources, found #{faces.size}"
    assert_equal 12, faces.uniq.size, "two faces point at the same file"

    faces.each do |face|
      assert_no_match %r{\A(?:https?:)?//}, face, "#{face} is not served by this app"

      get face

      assert_response :success, "#{face} is referenced by the stylesheet but does not resolve"
    end
  end

  test "every face keeps both variable axes live" do
    get "/"
    get css_select("link[rel=stylesheet]").first["href"]

    # `font-weight` as a range is what tells the browser the file is variable.
    # A static-weight substitution would flatten `opsz`, which is the only
    # reason the masthead and the wall label are drawn differently at their
    # different sizes — a visual regression wearing an optimisation's clothes.
    assert_equal 6, response.body.scan(/font-weight: 300 700;/).size, "Fraunces lost its weight range"
    assert_equal 6, response.body.scan(/font-weight: 300 600;/).size, "Newsreader lost its weight range"
    assert_not_includes response.body, "font-variation-settings: \"SOFT\"",
      "an axis the design does not use came back"
  end

  # The OFL requires the licence to travel with the files. This is the only
  # place that obligation can fail quietly.
  test "the licence ships with the fonts" do
    %w[Fraunces Newsreader].each do |family|
      path = Rails.root.join("app/assets/fonts/OFL-#{family}.txt")

      assert path.exist?, "#{family} is redistributed without its OFL licence text"
      assert_includes path.read, "SIL Open Font License"
    end
  end
end
