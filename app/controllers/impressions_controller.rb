# The reader's answer to the day's prompt (story 0032, redesigned 2026-09-01).
#
# ONE caller: the front door's impression frame, which ships with NO `src` —
# `sit_controller` points it here on connect (the folded page asks for the
# field, a revealed page asks with `after=reveal`). So the fetch happens once
# per front-door open, the Keep frame's own cost, and the cached page stays
# byte-identical.
#
#   GET /                              GET /impression/42/control
#     public, no-cache, ETag             private, no-store
#     inert frame, no src                ├─ user, pre-reveal → the field
#          │                            │    (prefilled with today's draft)
#          └── sit_controller ──────────├─ user, after=reveal → the answer,
#              sets frame.src           │    read-only (or nothing)
#                                       ├─ anyone else, pre-reveal → the
#                                       │    sign-in hint (plain text, no
#                                       │    link, no form, no cookie)
#                                       └─ anyone else, after=reveal → nothing
#                                       (never a bounce: a 303 has no matching
#                                        frame and Turbo would write "Content
#                                        missing" over the front door)
#
# The branch is `current_user`, NEVER `identified?` (eng OV2): a registered
# device passes the wall and would otherwise be handed a field whose POST
# violates `impressions.user_id NOT NULL`. Devices keep favorites
# (decisions/0005); answers are account-backed (owner call, 2026-08-31).
class ImpressionsController < ApplicationController
  # Same skip, same reason as `favorites#control` — the null state of a
  # personal fragment on a public page is answered, not bounced.
  skip_before_action :require_reader, only: :control

  # Never cached anywhere, by anyone — class-wide so a later action cannot
  # forget it (the favorites idiom).
  before_action :no_store
  before_action :set_painting

  def control
    render_control
  end

  # Autosave's endpoint: create-or-update, a DRAFT until the reveal (owner
  # decision 2026-09-01, amending D6). The client debounces; the server
  # upserts. The prompt is stamped server-side from the painting's own pick —
  # never trusted from the request.
  def create
    # The wall let a registered device through; the field never renders for
    # one, so a device POST here is a hand-rolled request, not a UI path.
    return head :forbidden unless current_user

    @impression = current_user.impressions.find_or_initialize_by(painting: @painting)
    @impression.body = params[:body]
    @impression.prompt ||= DailyPick.find_by(painting: @painting)&.sit_prompt

    if @impression.save
      head :no_content # autosave ignores the body; nothing to render
    else
      head :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Two autosaves racing past find_or_initialize: the index decides; the
    # loser retries once as a plain update of the winner's row.
    current_user.impressions.find_by!(painting: @painting).update(body: params[:body]) ?
      head(:no_content) : head(:unprocessable_entity)
  end

  private

    # One template for every read: field, answer, hint, or nothing. The
    # frame id must always match the front door's inert frame, whatever the
    # state — an unmatched response is the "Content missing" bug.
    def render_control
      impression = current_user&.impressions&.find_by(painting: @painting)
      render partial: "impressions/control",
             locals: { painting: @painting, impression: impression,
                       revealed: params[:after].present? }
    end

    def set_painting
      @painting = Painting.find(params[:painting_id])
    end
end
