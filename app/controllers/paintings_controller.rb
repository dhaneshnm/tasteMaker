class PaintingsController < ApplicationController
  PER_PAGE = 10

  def index
    @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
    offset = (@page - 1) * PER_PAGE

    # Story 0022 Release 1. Resolution happens once, here — the controller
    # never touches a raw slug again after this. An unknown or absent slug
    # resolves to nil, which is indistinguishable from "no filter": the
    # graceful-degradation the plan calls out (a stale bookmark after a
    # Release 2 value rename just lands on the unfiltered gallery).
    @period = Painting.resolve_facet_slug(:period, params[:period])
    @genre = Painting.resolve_facet_slug(:genre, params[:genre])
    @filtered = @period.present? || @genre.present?

    scope = Painting.with_attached_image.feed_ordered
    scope = scope.where(period: @period) if @period
    scope = scope.where(genre: @genre) if @genre

    @paintings = scope.offset(offset).limit(PER_PAGE)

    # One `Painting.count`, not two (story 0020, `/plan-eng-review` P1). The
    # two calls below used to be independent `Painting.count`s — an identical
    # `COUNT(*)` twice per request, on every one of the eleven lazy pagination
    # fetches a full scroll makes. Filtered now (story 0022): this is the
    # count of the SCOPE, not the whole pool, so the masthead aside and the
    # "any matches?" check both read the filtered number.
    @total = scope.count
    @next_page = @page + 1 if @total > offset + PER_PAGE

    # The two facet rows — non-empty values only (Painting.displayed_facet_values
    # already applies the floor), and the slugs each row's links carry to
    # preserve the OTHER active facet when a reader switches one.
    @period_values = Painting.displayed_facet_values(:period)
    @genre_values = Painting.displayed_facet_values(:genre)
    @filter_params = {
      period: (Painting.facet_slug(@period) if @period),
      genre: (Painting.facet_slug(@genre) if @genre)
    }.compact

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
