module Admin
  class DailyPicksController < BaseController
    before_action :set_pick, only: %i[edit update destroy preview]

    def index
      @picks = DailyPick.with_artwork.order(scheduled_on: :desc)
    end

    def new
      @pick = DailyPick.new(scheduled_on: DailyPick.first_open_date)
      load_selectable_paintings
    end

    def create
      @pick = DailyPick.new(pick_params)

      if @pick.save
        redirect_to admin_daily_picks_path, notice: "Scheduled for #{@pick.scheduled_on.to_fs(:long)}."
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
        redirect_to admin_daily_picks_path, notice: "Updated #{@pick.scheduled_on.to_fs(:long)}."
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
      @pick = DailyPick.with_artwork.find(params[:id])
    end

    # Paintings that have not had their day yet, plus whichever one this pick
    # already holds — otherwise a record disappears from its own edit form.
    def load_selectable_paintings
      spoken_for = DailyPick.where.not(id: @pick&.id).select(:painting_id)
      # The picker renders a thumbnail per option, so load the attachments with
      # the list rather than one lookup per painting.
      @paintings = Painting.with_attached_image.where.not(id: spoken_for).order(:title)
    end

    def pick_params
      params.expect(daily_pick: [ :painting_id, :scheduled_on, :blurb ])
    end
  end
end
