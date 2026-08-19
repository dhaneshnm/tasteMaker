# Everything Tondo holds by one hand (story 0018). Reached only from a linked
# artist name on `/feed` or `/days/:date` — see `shared/_artist_line` — never
# from the compass and never self-linking.
class ArtistsController < ApplicationController
  # A different class than `ActiveRecord::RecordNotFound`, on purpose.
  # `ErrorsController::MESSAGES` keys off the exact exception class, and a
  # bare `RecordNotFound` here would answer an unknown slug with "There was no
  # artwork on that day." (eng review D6).
  class NotFound < ActiveRecord::RecordNotFound; end

  def show
    matches = Painting.where(artist_slug: params[:slug])

    # Behind the wall since story 0015: still ETag'd, no longer `public` —
    # see ApplicationController#private_revalidate. Same contract as `/days`.
    private_revalidate

    # NO manual `stale?` any more (story 0020, `/plan-eng-review` A1 — this
    # deletes what an earlier draft of that story added, a `[count, latest]`
    # aggregate that this comment used to describe).
    #
    # The old aggregate knew nothing about the reader's favorites, so once
    # this page's body started carrying kept marks (below), a reader who kept
    # a work and revisited got a 304 back holding the stale outline mark —
    # silently, the exact class of bug `stale_when_importmap_changes`'s
    # comment in ApplicationController is about.
    #
    # `Rack::ETag` (`rack/etag.rb`) already digests the response BODY on every
    # 200, and skips only when an ETag or Last-Modified header is already
    # set — so deleting the manual one restores an automatic ETag that is
    # inherently per-reader-correct: change a kept mark, change the body,
    # change the digest. `Rack::ConditionalGet` still turns a matching digest
    # into a 304 on a repeat, unchanged visit.
    #
    # What is genuinely given up: the old code bailed before
    # `with_attached_image` loaded attachments and blobs, so a 304 cost
    # nothing server-side (E-A2/E-A3, two 0018 reviews). That skip is gone —
    # the body must now be rendered to be digested, on every request, even
    # one that ends in 304. Accepted on a page bounded at 9 works; recorded
    # in `test/integration/artists_test.rb` rather than left to be
    # rediscovered.
    @paintings = matches.with_attached_image.feed_ordered.to_a
    raise NotFound if @paintings.empty?

    @heading = Painting.canonical_artist_name(@paintings.map(&:artist))
    @life_date = uniform_life_date(@paintings)
    @kept_ids = kept_ids_for(@paintings)
  end

  private
    # Shown under the heading only when every work agrees — a mix of dates or
    # formats belongs to no single fact worth stating there.
    def uniform_life_date(paintings)
      dates = paintings.filter_map { |painting| painting.life_date.presence }.uniq
      dates.first if dates.one?
    end
end
