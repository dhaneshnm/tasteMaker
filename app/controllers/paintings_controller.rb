class PaintingsController < ApplicationController
  PER_PAGE = 10

  def index
    @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
    offset = (@page - 1) * PER_PAGE
    @paintings = Painting.with_attached_image.feed_ordered.offset(offset).limit(PER_PAGE)

    # One `Painting.count`, not two (story 0020, `/plan-eng-review` P1). The
    # two calls below used to be independent `Painting.count`s — an identical
    # `COUNT(*)` twice per request, on every one of the eleven lazy pagination
    # fetches a full scroll makes.
    @total = Painting.count
    @next_page = @page + 1 if @total > offset + PER_PAGE

    # `/feed` is walled and private (story 0015) — no shared cache to poison,
    # so unlike `/` this page can render the reader's own state inline. One
    # indexed query for the whole page (`kept_ids_for`), not one fetch per
    # work; see `paintings/_painting.html.erb`. No `no_store`: `Rack::ETag`
    # already digests the response body, which now includes these marks, so
    # the automatic ETag is already per-reader-correct (`ArtistsController`
    # carries the fuller reasoning, since it deletes a manual one).
    @kept_ids = kept_ids_for(@paintings)
  end
end
