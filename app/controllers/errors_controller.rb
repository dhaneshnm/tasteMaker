# The page that isn't there.
#
# Reached through `config.exceptions_app`, so it renders the reader's layout like
# any other screen — one skin, `DESIGN.md` rule 1. It is the only controller that
# exists to answer a request that already failed.
class ErrorsController < ApplicationController
  # Two ways to arrive, and they deserve different sentences.
  #
  # A date that has no artwork raised RecordNotFound out of DaysController; a
  # typo'd URL raised RoutingError before any controller ran. Both are 404s, but
  # only one of them is about a day. Reading the original exception tells them
  # apart without parsing the path to guess what the reader meant.
  MESSAGES = {
    ActiveRecord::RecordNotFound => "There was no artwork on that day."
  }.freeze

  DEFAULT_MESSAGE = "That page does not exist."

  def not_found
    @message = MESSAGES.fetch(original_exception.class, DEFAULT_MESSAGE)

    # `status:` is the whole point. This is a styling change, not a redirect: a
    # guessable URL for a queued day must keep answering 404, or the archive's
    # no-leak rule becomes a soft suggestion.
    render status: :not_found
  end

  private
    def original_exception
      request.env["action_dispatch.exception"]
    end
end
