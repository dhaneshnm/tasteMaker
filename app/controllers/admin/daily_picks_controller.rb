module Admin
  class DailyPicksController < BaseController
    before_action :set_pick, only: %i[edit update destroy]
    before_action :set_pick_with_artwork, only: :preview

    def index
      # The queue lists titles, not pictures, so the images stay unloaded.
      @picks = DailyPick.includes(:painting).order(scheduled_on: :desc).to_a
      # Derived from @picks rather than two more queries — the full table is
      # already in hand (simplify pass).
      future = @picks.select { |pick| pick.scheduled_on >= Date.current }
      @days_scheduled_ahead = future.size
      @scheduled_through = future.map(&:scheduled_on).max
    end

    def new
      @pick = DailyPick.new(scheduled_on: DailyPick.first_open_date)
      load_selectable_paintings
    end

    def create
      @pick = DailyPick.new(pick_params)

      if @pick.save
        redirect_to admin_daily_picks_path, notice: "Scheduled for #{@pick.scheduled_on.to_fs(:daily_long)}."
      else
        load_selectable_paintings
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_selectable_paintings
    end

    def update
      if @pick.update(pick_params)
        redirect_to admin_daily_picks_path, notice: "Updated #{@pick.scheduled_on.to_fs(:daily_long)}."
      else
        load_selectable_paintings
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Deleting a future machine pick is a re-roll, not a veto (story 0021,
      # outside voice O7) — the date refills at the next 05:00, possibly with
      # the same painting, since there is no rejected-memory. Swap the
      # painting in place to actually overrule the machine; say so here,
      # once, at the moment the curator could otherwise be surprised by it.
      reroll = @pick.reroll_on_delete?
      @pick.destroy!
      notice = reroll ? "Removed — the machine refills this day tomorrow morning. Swap the painting instead to overrule it." : "Removed from the queue."
      redirect_to admin_daily_picks_path, notice: notice
    end

    # Renders the real public page for this pick so the curator sees the exact
    # fold behaviour — title length against aspect ratio against blurb — before
    # it goes live.
    def preview
      # :preview, not :front_door — the curator should see the reader's page, not
      # one carrying a live link into an archive this day is not in yet.
      #
      # `layout: "application"` for the same reason: the namespace now defaults to
      # the admin layout, and a preview wrapped in admin chrome stops being a
      # preview of what a reader sees.
      @chrome = :preview
      render template: "daily/show", layout: "application"
    end

    private

    def set_pick
      @pick = DailyPick.find(params[:id])
    end

    # Only the preview renders the artwork itself.
    def set_pick_with_artwork
      @pick = DailyPick.with_artwork.find(params[:id])
    end

    def load_selectable_paintings
      @paintings = DailyPick.selectable_paintings(@pick)
    end

    def pick_params
      params.expect(daily_pick: [ :painting_id, :scheduled_on, :blurb ])
    end
  end
end
