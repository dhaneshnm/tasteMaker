# The reader's one line, written before the note (story 0032).
#
# ONE caller, unlike Keep's two: the front door's impression frame — which
# ships with NO `src` and is pointed here by `sit_controller` only when the
# minute completes (plan D5/E3). So this controller never renders inline on a
# walled surface, and the fetch only ever happens for a reader who sat.
#
#   GET /                            GET /impression/42/control  (minute done)
#     public, no-cache, ETag           private, no-store
#     inert frame, no src              ├─ signed-in user, no line → the field
#          │                           ├─ signed-in user, has line → the line
#          └── sit_controller ─────────├─ device or nobody → empty frame
#              sets frame.src          └─ (never a bounce: a 303 has no
#                                          matching frame and Turbo would
#                                          write "Content missing" over the
#                                          front door — favorites#control's
#                                          comment is the precedent)
#
# The branch is `current_user`, NEVER `identified?` (eng OV2): a registered
# device passes the wall and would otherwise be handed a field whose POST
# violates `impressions.user_id NOT NULL`. Devices keep favorites
# (decisions/0005); impressions are account-backed (owner call, 2026-08-31).
class ImpressionsController < ApplicationController
  # Same skip, same reason as `favorites#control` — the null state of a
  # personal fragment on a public page is answered, not bounced. Leaks less
  # than Keep's: with no form there is no CSRF token, so no session and no
  # `Set-Cookie` at all (asserted in public_cache_headers_test).
  skip_before_action :require_reader, only: :control

  # Never cached anywhere, by anyone — class-wide so a later action cannot
  # forget it (the favorites idiom).
  before_action :no_store
  before_action :set_painting

  def control
    render_control
  end

  # Write-once, ink (D6): a second line for the same painting is rejected by
  # the unique index and the uniqueness validation both — the validation for
  # the honest 422, the index for the race two tabs could win. Submitting
  # does NOT open the note: writing is not consent to reveal.
  def create
    # The wall let a registered device through; the field never renders for
    # one, so a device POST here is a hand-rolled request, not a UI path.
    return head :forbidden unless current_user

    @impression = current_user.impressions.build(
      painting: @painting, body: params[:body]
    )
    if @impression.save
      render_control
    else
      render_control status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Two submits racing past the validation: the index decides, the loser
    # re-renders the winner's line rather than an error — the reader's line
    # exists, which is what they asked for.
    @impression = nil
    render_control
  end

  private

    # One template for every answer: line, field, error, or nothing. The
    # frame id must always match the front door's inert frame, whatever the
    # state — an unmatched response is the "Content missing" bug.
    #
    # `after=reveal` (sit_controller's revealed-revisit fetch) asks for the
    # line WITHOUT the field: once the note is read, the writing moment is
    # over (D5 — foreclosure is intended), and the client saying so is
    # trusted because the worst a liar wins is seeing a form.
    def render_control(status: :ok)
      @impression = current_user&.impressions&.find_by(painting: @painting) if @impression.nil?
      render partial: "impressions/control",
             locals: { painting: @painting, impression: @impression,
                       offer_field: params[:after].blank? },
             status: status
    end

    def set_painting
      @painting = Painting.find(params[:painting_id])
    end
end
