require "test_helper"

module Admin
  class DailyPicksTest < ActionDispatch::IntegrationTest
    test "the curator's desk is locked" do
      get admin_daily_picks_path
      assert_response :unauthorized

      get new_admin_daily_pick_path
      assert_response :unauthorized

      post admin_daily_picks_path, params: { daily_pick: { painting_id: paintings(:woodcut).id } }
      assert_response :unauthorized
    end

    test "a wrong password does not open it" do
      get admin_daily_picks_path, headers: curator_headers(password: "guess")

      assert_response :unauthorized
    end

    # The receipt for decisions/0004. A museum day reads "0" in a word count,
    # which is indistinguishable from a data error, and the prediction the kill
    # review turns on is a ratio nobody will compute by hand.
    test "the queue names museum days and states the ratio against the bet" do
      daily_picks(:today).update!(blurb: nil)

      get admin_daily_picks_path, headers: curator_headers

      assert_select ".adm__queue td", text: "museum text"
      assert_select ".adm__hint", /1 of 2 published days/
      assert_select ".adm__hint", /50%/
      assert_select ".adm__hint.is-off-target"
    end

    test "a queue where every day was written says nothing about ratios" do
      get admin_daily_picks_path, headers: curator_headers

      assert_select ".adm__hint", count: 0
    end

    test "a day with no note can be scheduled from the desk" do
      assert_difference -> { DailyPick.count } do
        post admin_daily_picks_path, headers: curator_headers, params: {
          daily_pick: { painting_id: paintings(:woodcut).id,
                        scheduled_on: 3.days.from_now.to_date, blurb: "" }
        }
      end

      assert_nil DailyPick.order(:created_at).last.blurb
    end

    test "the queue lists what is scheduled, newest first" do
      get admin_daily_picks_path, headers: curator_headers

      assert_response :success
      assert_select ".adm__queue tbody tr", count: 3
      assert_select "tr.is-upcoming", count: 1
    end

    test "a new day is offered the first free date from today" do
      get new_admin_daily_pick_path, headers: curator_headers

      assert_response :success
      assert_select "input[name=?][value=?]",
        "daily_pick[scheduled_on]", DailyPick.first_open_date.iso8601
    end

    test "the picker offers only paintings that have not had their day" do
      get new_admin_daily_pick_path, headers: curator_headers

      assert_select "select[name=?] option[value=?]", "daily_pick[painting_id]", paintings(:woodcut).id.to_s
      assert_select "select[name=?] option[value=?]", "daily_pick[painting_id]", paintings(:sunflowers).id.to_s, count: 0
    end

    test "editing a day keeps its own painting in the picker" do
      get edit_admin_daily_pick_path(daily_picks(:today)), headers: curator_headers

      assert_response :success
      assert_select "select[name=?] option[value=?]",
        "daily_pick[painting_id]", paintings(:sunflowers).id.to_s
    end

    test "scheduling a day puts it in the queue" do
      target = DailyPick.first_open_date

      assert_difference -> { DailyPick.count }, 1 do
        post admin_daily_picks_path,
          params: { daily_pick: { painting_id: paintings(:woodcut).id, scheduled_on: target, blurb: "A note about the rain." } },
          headers: curator_headers
      end

      assert_redirected_to admin_daily_picks_path
      assert_equal paintings(:woodcut), DailyPick.find_by(scheduled_on: target).painting
    end

    test "double-booking a date is refused out loud" do
      assert_no_difference -> { DailyPick.count } do
        post admin_daily_picks_path,
          params: { daily_pick: { painting_id: paintings(:woodcut).id, scheduled_on: Date.current, blurb: "A note." } },
          headers: curator_headers
      end

      assert_response :unprocessable_entity
      assert_select ".adm__errors", /already has an artwork scheduled/
    end

    test "a painting with no picture is refused out loud" do
      post admin_daily_picks_path,
        params: { daily_pick: { painting_id: paintings(:imageless).id, scheduled_on: DailyPick.first_open_date, blurb: "A note." } },
        headers: curator_headers

      assert_response :unprocessable_entity
      assert_select ".adm__errors", /no usable image/
    end

    test "a note can be fixed" do
      patch admin_daily_pick_path(daily_picks(:today)),
        params: { daily_pick: { blurb: "The corrected note." } },
        headers: curator_headers

      assert_redirected_to admin_daily_picks_path
      assert_equal "The corrected note.", daily_picks(:today).reload.blurb
    end

    test "a day can be pulled from the queue" do
      assert_difference -> { DailyPick.count }, -1 do
        delete admin_daily_pick_path(daily_picks(:tomorrow)), headers: curator_headers
      end
    end

    test "preview is behind the same lock as the rest of the desk" do
      get preview_admin_daily_pick_path(daily_picks(:tomorrow))

      assert_response :unauthorized
      assert_no_match paintings(:bronze).title, response.body
    end

    test "preview shows the curator the real page for a queued day" do
      get preview_admin_daily_pick_path(daily_picks(:tomorrow)), headers: curator_headers

      assert_response :success
      assert_select "h1.label__title", text: paintings(:bronze).title
      assert_select "time.masthead__aside[datetime=?]", 1.day.from_now.to_date.iso8601
      assert_select ".label__note", /ritual meal/
    end

    # Story 0007. The namespace now defaults to the admin layout, so the preview
    # has to opt back out or the curator is looking at admin chrome and calling it
    # a preview of the reader's page.
    test "preview renders in the reader's layout, not the admin one" do
      with_forgery_protection do
        get preview_admin_daily_pick_path(daily_picks(:tomorrow)), headers: curator_headers

        assert_select "meta[name=?]", "csrf-token", count: 0,
          message: "the preview rendered the admin layout"
        assert_select "a.masthead__brand", text: "Tastemaker"
      end
    end

    # The queue deletes a day with `data: { turbo_method: :delete }`, which is
    # JS reading `meta[name=csrf-token]`. An integration DELETE proves nothing
    # about that, because it never runs the JS — assert the tag itself is there.
    # test/system/admin_test.rb drives the real thing.
    test "the curator's desk still carries the CSRF meta tag the delete link needs" do
      with_forgery_protection do
        get admin_daily_picks_path, headers: curator_headers

        assert_select "meta[name=?]", "csrf-token", count: 1
        assert_select("meta[name=?]", "csrf-token").first["content"].then do |token|
          assert token.present?, "the CSRF meta tag rendered with no token in it"
        end
      end
    end
  end
end
