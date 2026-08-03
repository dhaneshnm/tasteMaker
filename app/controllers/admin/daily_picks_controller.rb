module Admin
  class DailyPicksController < BaseController
    before_action :set_pick, only: %i[edit update destroy]
    before_action :set_pick_with_artwork, only: :preview

    def index
      # The queue lists titles, not pictures, so the images stay unloaded.
      @picks = DailyPick.includes(:painting).order(scheduled_on: :desc).to_a
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
      @pick.destroy!
      redirect_to admin_daily_picks_path, notice: "Removed from the queue."
    end

    # Renders the real public page for this pick so the curator sees the exact
    # fold behaviour — title length against aspect ratio against blurb — before
    # it goes live.
    def preview
      render template: "daily/show"
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
