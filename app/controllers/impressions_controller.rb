# The reader's own comment (story 0033, replacing the sit gate's draft;
# `decisions/0023`).
#
# ONE caller per surface: the front door's frame ships with NO `src` —
# `sit_controller` points it at the plain control URL on connect, and again
# whenever the reader commits or taps their own comment to edit it
# (`?edit=1`). The archive's frame carries its `src` server-side, eagerly,
# with `view=answer` — matching Keep's own eager-frame idiom, and for the
# same reason: `/days/:date` is ETag-keyed on the pick and the painting
# only (`days_controller.rb`), never on the reader, so nothing reader-specific
# may ever render inside that cached body. The frame tag is identical for
# every visitor; only its FETCHED content, answered here with `no_store`, is
# per-visitor.
#
#   GET /                              GET /impression/42/control
#     public, no-cache, ETag             private, no-store
#     inert frame, no src                ├─ user, today's pick, no line → composer
#          │                            │    (prefilled if ?edit=1 mid-draft)
#          └── sit_controller ──────────├─ user, today's pick, has a line,
#              sets frame.src           │    not editing → the comment, tap to edit
#                                       ├─ anyone else, today's pick → the
#                                       │    prompt + sign-in hint (no link,
#                                       │    no form, no cookie)
#                                       └─ view=answer (archive only) → the
#                                            reader's line, read-only, or
#                                            NOTHING if they never wrote one
#                                       (never a bounce: a 303 has no matching
#                                        frame and Turbo would write "Content
#                                        missing" over the front door)
#
# The branch is `current_user`, NEVER `identified?` (eng OV2, carried from
# 0032): a registered device passes the wall and would otherwise be handed a
# field whose POST violates `impressions.user_id NOT NULL`. Devices keep
# favorites (decisions/0005); answers are account-backed (owner call,
# 2026-08-31) — a device sees the same prompt + hint an anonymous visitor
# does.
#
# The day-end ink boundary (eng OV1) is a READ-side fact, not a write-side
# check: `render_control` never composes a composer or an edit button for
# any painting but today's, so no UI route to `create`/update ever survives
# past midnight. `create` itself stays deliberately date-blind (eng Q2,
# carried from 0032, still true here) — it accepts a POST for ANY existing
# painting a signed-in reader names, rollover or not. A hand-rolled request
# past the UI can still land a line on an old day; that is accepted, not
# missed (harmless: 280 chars of the requester's own words, on a row only
# they and the archive's read-only view will ever show).
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

  # Create, update, or delete, in one action: the client debounces and the
  # server upserts, same as before. Blank is new here (eng OV2, amending
  # decisions/0022's write-once a second time) — the ink boundary moved to
  # the day's end, so a reader who empties their line while the day is still
  # theirs is asking to take it back, not filing a validation error.
  def create
    # The wall let a registered device through; the field never renders for
    # one, so a device POST here is a hand-rolled request, not a UI path.
    return head :forbidden unless current_user

    body = params[:body].to_s.strip
    @impression = current_user.impressions.find_by(painting: @painting)

    if body.blank?
      @impression&.destroy
      return head :no_content
    end

    @impression ||= current_user.impressions.build(painting: @painting)
    @impression.body = body
    @impression.prompt ||= DailyPick.find_by(painting: @painting)&.sit_prompt

    if @impression.save
      head :no_content # autosave ignores the body; nothing to render
    else
      head :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Two autosaves racing past find_by: the index decides; the loser
    # retries once as a plain update of the winner's row. A third request
    # deleting that row in the same instant is a real, if tiny, window —
    # `find_by` (not `find_by!`) so that lands as a no-op, not a 500.
    winner = current_user.impressions.find_by(painting: @painting)
    if winner&.update(body: body)
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  private

    # One template for every read: composer, comment, hint, or nothing. The
    # frame id must always match the caller's inert frame, whatever the
    # state — an unmatched response is the "Content missing" bug.
    def render_control
      impression = current_user&.impressions&.find_by(painting: @painting)
      archived = params[:view] == "answer"
      editing = params[:edit].present?
      answered = current_user && impression && !editing

      render partial: "impressions/control",
             locals: {
               painting: @painting,
               # The prompt only ever labels the composer or the hint — never
               # the archived read-only line nor today's own answered
               # comment — so the two states that never render it never pay
               # for the query either.
               pick: (DailyPick.find_by(painting: @painting) unless archived || answered),
               impression: impression,
               archived: archived,
               editing: editing,
               # Computed once here, not re-derived in the view — a second
               # copy of this exact condition drifting from this one is how
               # the answered state and the prompt query above stop agreeing.
               answered: answered
             }
    end

    def set_painting
      @painting = Painting.find(params[:painting_id])
    end
end
