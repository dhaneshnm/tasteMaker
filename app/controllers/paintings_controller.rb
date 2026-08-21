class PaintingsController < ApplicationController
  PER_PAGE = 10

  def index
    @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
    offset = (@page - 1) * PER_PAGE

    # Story 0022 Release 1 (period, genre), extended by 0024 (tradition).
    # Resolution happens once, here, driven off `Painting::FACETS` rather
    # than one hand-copied block per facet (0024 eng review + simplify: three
    # near-identical blocks invited exactly the bug class this story already
    # fixed once — a facet missing from `@filter_params` silently drops at
    # lazy page 2, bug `5d90908`). A fourth facet extends the constant; it
    # cannot omit a step here the way a fourth copy-pasted block could.
    #
    # An unknown or absent slug resolves to nil, which is indistinguishable
    # from "no filter": the graceful-degradation the plan calls out (a stale
    # bookmark after a facet-value rename just lands on the unfiltered
    # gallery).
    # One `facet_counts` query per facet for the whole request (0024 code
    # review) — `resolve_facet_slug` and `displayed_facet_values` below both
    # need it; passing it in once avoids two `GROUP BY`s per facet.
    counts = Painting::FACETS.index_with { |facet| Painting.facet_counts(facet) }
    @active = Painting::FACETS.index_with { |facet| Painting.resolve_facet_slug(facet, params[facet], counts: counts[facet]) }
    @filtered = @active.values.any?

    scope = Painting.with_attached_image.feed_ordered
    @active.each { |facet, value| scope = scope.where(facet => value) if value }

    @paintings = scope.offset(offset).limit(PER_PAGE)

    # One `Painting.count`, not two (story 0020, `/plan-eng-review` P1). The
    # two calls below used to be independent `Painting.count`s — an identical
    # `COUNT(*)` twice per request, on every one of the eleven lazy pagination
    # fetches a full scroll makes. Filtered now (story 0022): this is the
    # count of the SCOPE, not the whole pool, so the masthead aside and the
    # "any matches?" check both read the filtered number.
    @total = scope.count
    @next_page = @page + 1 if @total > offset + PER_PAGE

    # The facet rows — non-empty values only (Painting.displayed_facet_values
    # already applies the floor), and the slugs each row's links carry to
    # preserve the OTHER active facets when a reader switches one. Keyed by
    # facet so the view can loop `Painting::FACETS` too.
    @facet_values = Painting::FACETS.index_with { |facet| Painting.displayed_facet_values(facet, counts: counts[facet]) }
    @filter_params = @active.filter_map { |facet, value| [ facet, Painting.facet_slug(value) ] if value }.to_h

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
