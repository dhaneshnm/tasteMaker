require "test_helper"

class FavoritesTest < ActionDispatch::IntegrationTest
  setup do
    @painting = paintings(:harbour)          # yesterday's day
    @today = daily_picks(:today)
    @yesterday = daily_picks(:yesterday)
  end

  # ---------------------------------------------------------------- the cache
  #
  # The reason the control is a fragment at all. `/` and `/days` are
  # `Cache-Control: public` and production sits behind Thruster's HTTP cache, so
  # the public HTML must be identical for everyone and must not carry a cookie.
  # Every one of these runs with forgery protection ON — see with_forgery_protection.

  test "mounting the keep frame puts no cookie back on a public page" do
    keep(@painting)   # this session now holds a collector cookie

    # Protection goes on only for the reads: a public page that renders a CSRF
    # token is the thing that writes the session, and with protection off it
    # renders none, so without this the assertion would hold against any layout.
    with_forgery_protection do
      %W[/ /days #{day_path(@yesterday.scheduled_on.iso8601)}].each do |path|
        get path

        assert_response :success
        assert_nil response.headers["Set-Cookie"], "#{path} set a cookie"
      end
    end
  end

  test "the front door is byte-identical whether or not the reader has a collection" do
    get root_path
    empty_handed = response.body
    empty_etag = response.headers["ETag"]

    keep(@painting)
    keep(paintings(:woodcut))
    get root_path

    assert_equal empty_etag, response.headers["ETag"], "the ETag moved with the reader"
    assert_equal empty_handed, response.body, "the front door leaked per-visitor state"
  end

  test "the archive's collection door is countless, so it too is identical for everyone" do
    get days_path
    empty_handed = response.body

    assert_select ".compass a[href=?]", collection_path, text: "Kept"

    keep(@painting)
    get days_path

    assert_equal empty_handed, response.body, "the archive door became per-visitor"
  end

  test "everything personal is private and unstorable" do
    [ favorite_control_path(@painting), collection_path ].each do |path|
      get path

      assert_response :success
      assert_match(/private/, response.headers["Cache-Control"], "#{path} is not private")
      assert_match(/no-store/, response.headers["Cache-Control"], "#{path} is storable")
      assert_equal "Cookie", response.headers["Vary"], "#{path} does not vary on the cookie"
    end
  end

  # ------------------------------------------------------------- the identity

  test "reading the control issues the reader's cookie, once" do
    get favorite_control_path(@painting)

    assert_response :success
    minted = set_cookie_header
    assert minted.present?, "the control did not issue a cookie"
    assert_match(/collector=/, minted)

    get favorite_control_path(@painting)

    assert_nil response.headers["Set-Cookie"], "a second read minted a second identity"
  end

  # This, and not a pretend browser restart, is what proves a collection survives
  # quitting the app. A new Capybara session gets a clean profile, so the system
  # test people reach for first cannot assert this at all.
  test "the cookie is built to outlive the browser session" do
    get favorite_control_path(@painting)
    header = set_cookie_header

    assert_match(/httponly/i, header, "the cookie is reachable from script")
    assert_match(/samesite=lax/i, header)
    expires = header[/expires=([^;]+)/i, 1]
    assert expires.present?, "a session cookie: the collection would die on quit"
    assert_operator Time.httpdate(expires), :>, 5.years.from_now,
      "the cookie expires too soon to hold a collection"
  end

  test "a returning reader with the same cookie finds the same collection" do
    keep(@painting)
    carried = cookies[:collector]

    returning = open_session
    returning.cookies[:collector] = carried
    returning.get collection_path

    returning.assert_select ".days__title", text: @painting.title
  end

  test "the table stores a digest, never anything the cookie carries" do
    keep(@painting)

    stored = Favorite.order(:created_at).last.collector_digest

    assert_match(/\A[0-9a-f]{64}\z/, stored)
    assert_not_equal cookies[:collector], stored
    assert_not_includes cookies[:collector].to_s, stored
  end

  test "a keep from a reader with no cookie yet still works" do
    post favorite_path(@painting)

    assert_response :success
    assert_select "button[aria-pressed=?]", "true"
    assert set_cookie_header.present?, "the fallback mint did not fire"
  end

  # Story 0014's other half. Moving the control under the artwork fixed WHERE it
  # is; this is what fixes WHETHER IT IS THERE YET. The frame is fetched, so
  # without default content the rail paints an empty hole in the spot a reader is
  # now looking at — the same bug, moved from the bottom of the page to the top.
  #
  # The cached page carries the mark and none of the machinery. That split is not
  # tidiness: `button_to` emits a CSRF token, generating one starts a session, and
  # a session puts a Set-Cookie on a page Thruster caches for everyone — which is
  # the assertion directly above this one. So the placeholder is a <span>.
  test "the cached page draws the keep mark without minting a session" do
    with_forgery_protection do
      get root_path

      assert_select "turbo-frame#keep_#{@today.painting_id} .rail__act--waiting svg", count: 1,
        message: "the rail had no keep mark until the private fragment landed"
      assert_select "turbo-frame#keep_#{@today.painting_id} button", count: 0,
        message: "a real button in the cached page mints a CSRF token and a cookie"
      assert_select "a.rail__count", count: 0,
        message: "a per-visitor count leaked into the publicly cached page"
      assert_nil response.headers["Set-Cookie"]
    end
  end

  # A work with no picture renders no <img>, so the JS that hides a dead zoom
  # control can never fire for it — that path is an error event on an element
  # which was never there. The guard has to be in the template or the rail ships
  # a live Zoom that opens an empty overlay. Keeping still works: a resting work
  # is still a work you can keep.
  test "a work with no picture offers no zoom in the rail, but still offers keep" do
    @today.painting.update!(image_url_800: nil)

    get root_path

    assert_select ".plate__resting"
    assert_select ".rail__act[data-artwork-target=?]", "railZoom", count: 0
    assert_select "turbo-frame#keep_#{@today.painting_id}", count: 1
  end

  # ---------------------------------------------------------------- the toggle

  test "keeping and letting go" do
    keep(@painting)
    get favorite_control_path(@painting)

    # No visible words since story 0014 — the state is the glyph's fill and the
    # accessible name, so those are what this asserts. A test looking for text
    # here would be looking for something the product deliberately does not say.
    assert_select "button[aria-pressed=?]", "true"
    assert_select "button[aria-label=?]", "Remove #{@painting.title} from your collection"
    assert_select "button svg[fill=?]", "currentColor"

    unkeep(@painting)

    assert_select "button[aria-pressed=?]", "false"
    assert_select "button[aria-label=?]", "Keep #{@painting.title} in your collection"
    assert_select "button svg[fill=?]", "none"
  end

  test "two taps that race keep one work, not two rows and a 500" do
    keep(@painting)

    assert_difference -> { Favorite.count }, 0 do
      post favorite_path(@painting)
    end
    assert_response :success
    assert_select "button[aria-pressed=?]", "true"
    # The rescue path is still a write the reader triggered, so focus comes back
    # to the toggle exactly as it does on the success path.
    assert_select "button[autofocus]"
  end

  # destroy has two callers with two different needs, and answering both the same
  # way is what broke the orphan row: Turbo Drive refuses a bare 200 for a
  # page-level form, so the row stayed on screen while the row was gone from the
  # table. The frame caller still wants the fragment.
  test "unkeeping answers the frame with a fragment and the page with a redirect" do
    keep(@painting)

    delete favorite_path(@painting), headers: { "Turbo-Frame" => "keep_#{@painting.id}" }

    assert_response :success
    assert_select "turbo-frame#keep_#{@painting.id}"

    keep(@painting)
    delete favorite_path(@painting)

    assert_redirected_to collection_path
    assert_response :see_other
  end

  test "letting go of something already gone is not an error" do
    get favorite_control_path(@painting)   # establish identity, keep nothing

    unkeep(@painting)

    assert_response :success
    assert_select "button[aria-pressed=?]", "false"
  end

  test "one reader never sees another's collection" do
    keep(@painting)

    stranger = open_session
    stranger.get favorite_control_path(@painting)

    stranger.assert_select "button[aria-pressed=?]", "false"

    stranger.get collection_path

    stranger.assert_select ".days__title", count: 0
  end

  test "keeping something that does not exist is a 404" do
    post "/collection/#{Painting.maximum(:id) + 1}"

    assert_response :not_found
  end

  # The suite disables forgery protection, so written without this wrapper the
  # assertion could never fail.
  test "a write without a valid CSRF token is refused" do
    with_forgery_protection do
      post favorite_path(@painting), params: { authenticity_token: "nonsense" }

      assert_response :unprocessable_content
      assert_equal 0, Favorite.collected_by(Digest::SHA256.hexdigest("x")).count
    end
  end

  # ------------------------------------------------------------ the collection

  test "the collection is in the reader's order, newest kept first" do
    keep(paintings(:harbour))
    keep(paintings(:sunflowers))

    get collection_path

    titles = css_select(".days__title").map(&:text)
    assert_equal [ paintings(:sunflowers).title, paintings(:harbour).title ], titles
  end

  test "the row for the work on the front door links to the front door, not a redirect" do
    keep(@today.painting)

    get collection_path

    assert_select "a.days__link[href=?]", root_path
    assert_select "a.days__link[href=?]", day_path(@today.scheduled_on.iso8601), count: 0
  end

  # The gap-day case, which is where keying on the calendar instead of on the
  # current pick goes wrong: today has no pick, so the front door is showing
  # yesterday's.
  test "on a gap day the canonical row is the pick the front door is actually showing" do
    @today.destroy!
    keep(@yesterday.painting)

    get collection_path

    assert_select "a.days__link[href=?]", root_path
  end

  test "a kept work whose day was removed stays, unlinked, and can still be let go" do
    keep(@painting)
    @yesterday.destroy!

    get collection_path

    assert_select "a.days__link", count: 0
    assert_select ".days__link--gone .days__title", text: @painting.title
    assert_select "form.days__remove-form"

    assert_difference -> { Favorite.count }, -1 do
      delete favorite_path(@painting)
    end
  end

  test "an empty collection promises, explains, and offers a way back" do
    get collection_path

    assert_select ".coda__line", text: "The works you keep will gather here."
    assert_select ".coda__note", text: "The bookmark under each artwork keeps it here."
    assert_select ".compass a[href=?]", root_path, text: "Today"
  end

  # Regression: ISSUE-001 — the empty collection offered only "Today →", so a
  # first-time reader who followed the archive's countless door had no way back
  # to the archive. The one screen in the product with no route to where the
  # reader came from.
  # Found by /qa on 2026-08-04
  # Report: .gstack/qa-reports/qa-report-localhost-2026-08-04-favorites.md
  #
  # Story 0012 answered it structurally: the compass carries every door on every
  # screen, so this cannot come back one page at a time. The assertion moved
  # onto the compass and stayed.
  test "an empty collection is still a sibling of the archive" do
    get collection_path

    assert_select ".compass a[href=?]", days_path, text: "Days"
    assert_select ".compass a[href=?]", root_path, text: "Today"
    assert_select ".compass span[aria-current=?]", "page", text: "Kept"
  end

  test "a collection that holds something says how it is held, and where else to go" do
    keep(@painting)

    get collection_path

    assert_select ".masthead__aside", text: "1 work"
    assert_select ".coda__note", text: "Kept on this device — free, and yours."
    assert_select ".compass a[href=?]", days_path, text: "Days"
    assert_select ".compass a[href=?]", root_path, text: "Today"
  end

  test "the count link appears only once there is something to count" do
    get favorite_control_path(@painting)

    assert_select "a.rail__count", count: 0

    post favorite_path(@painting)

    assert_select "a.rail__count", text: "1 kept"
  end

  test "collection thumbnails are thumbnails" do
    keep(@painting)

    get collection_path

    src = css_select(".days__thumb img").first["src"]
    assert_equal @painting.image_url_800, src,
      "the collection asked for something bigger than a 240px box needs"
  end

  # ------------------------------------------------------------- where it shows

  test "the frame is on the reader's pages and nowhere else" do
    get root_path
    assert_select "turbo-frame#keep_#{@today.painting_id}[src=?]",
      favorite_control_path(@today.painting)

    get day_path(@yesterday.scheduled_on.iso8601)
    assert_select "turbo-frame#keep_#{@yesterday.painting_id}"

    get preview_admin_daily_pick_path(daily_picks(:tomorrow)), headers: curator_headers
    assert_select "turbo-frame", count: 0,
      message: "the curator's preview offered a keep control on an unpublished day"
  end

  test "both list pages render the same row" do
    keep(@painting)

    get days_path
    archive = css_select(".days__day").first.to_s

    get collection_path
    collection = css_select(".days__day").first.to_s

    %w[days__text days__date days__title days__artist days__thumb].each do |part|
      assert_includes archive, part
      assert_includes collection, part, "the collection row drifted from the archive row"
    end
  end

  private
    def keep(painting)
      post favorite_path(painting)
      assert_response :success
    end

    # The day page's toggle lives inside the keep frame, so it sends the header
    # Turbo sends. Tests that omit it are exercising the page-level caller, which
    # gets a redirect instead — see the two-callers test above.
    def unkeep(painting)
      delete favorite_path(painting),
        headers: { "Turbo-Frame" => "keep_#{painting.id}" }
    end

    def set_cookie_header
      Array(response.headers["Set-Cookie"]).join("\n")
    end
end
