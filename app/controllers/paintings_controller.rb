class PaintingsController < ApplicationController
  PER_PAGE = 10

  # A different class than `ActiveRecord::RecordNotFound`, on purpose — see
  # `ArtistsController::NotFound`, the pattern this mirrors exactly.
  # `ErrorsController::MESSAGES` keys off the exact exception class, and a
  # bare `RecordNotFound` here would answer with "There was no artwork on
  # that day," which is about the wrong noun entirely.
  class NotFound < ActiveRecord::RecordNotFound; end

  def index
    @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
    offset = (@page - 1) * PER_PAGE

    load_active_filter

    scope = Painting.scoped_to(@active).with_attached_image.feed_ordered
    @paintings = scope.offset(offset).limit(PER_PAGE)

    # One `Painting.count`, not two (story 0020, `/plan-eng-review` P1). The
    # two calls below used to be independent `Painting.count`s — an identical
    # `COUNT(*)` twice per request, on every one of the eleven lazy pagination
    # fetches a full scroll makes. Filtered now (story 0022): this is the
    # count of the SCOPE, not the whole pool, so the masthead aside and the
    # "any matches?" check both read the filtered number.
    @total = scope.count
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

  # The wing label (story 0027) — the filter's own screen. Every value the
  # gallery can be narrowed by, as a plate (tradition, subject) or a caps
  # row (century), scoped to whatever is already active. A second action on
  # this controller rather than a controller of its own: it shares the
  # wall, the params, and the model calls `#index` already makes (eng
  # review D1) — the only new thing here is the view.
  def wings
    load_active_filter

    @index = Painting.index_for(@active)
    scope = Painting.scoped_to(@active)
    @total = scope.count

    @plates = Painting::FacetVoice::PLATE_FACETS.index_with do |facet|
      other_scope = Painting.scoped_to(@active.except(facet))
      @index[facet].to_h { |value, _count| [ value, Painting.plate_for(facet, value, scope: other_scope) ] }
    end

    @coverage = coverage_lines(@active, scope: scope, total: @total)
  end

  # The permanent address (story 0030) — every painting gets a page
  # independent of whether it was ever a Daily Pick. Walled by the default
  # `require_reader` (no skip), same contract as `/artists/:slug`: private,
  # no-store is the wrong trade for a page reached from a walled surface with
  # nothing public linking to it, so this stays `private_revalidate` + the
  # automatic `Rack::ETag` body digest, not a manual `stale?`.
  def show
    @painting = Painting.find_by(id: params[:id]) or raise NotFound

    private_revalidate
    @kept_ids = kept_ids_for([ @painting ])
  end

  private
    # One resolution per facet, shared by `#index` and `#wings` — the
    # `@filter_params` bug (`5d90908`) was a facet missing a step in one of
    # two copies of this; there is only one copy now. Also the one place
    # `@filtered`, `@filter_params`, and `@label` are set — both actions
    # need exactly these four, in this order (`/simplify`: they used to be
    # two copies of the same four lines).
    def load_active_filter
      @active = Painting::FACETS.index_with { |facet| Painting.resolve_facet_slug(facet, params[facet]) }
      @filtered = @active.values.any?
      @filter_params = @active.filter_map { |facet, value| [ facet, Painting.facet_slug(value) ] if value }.to_h
      @label = Painting::FacetVoice.label_for(@active)
    end

    # For each facet NOT already active, how much of the CURRENT scope
    # carries it — "Subject is known for 24 of 108 works," inside whatever
    # wing the reader is already standing in, never the facet that is
    # itself 100% known by construction (design review outside voice #4:
    # the active facet's own coverage is always 100% and says nothing).
    # Suppressed at 100% either way — a fully-tagged facet has nothing to
    # confess. `scope:`/`total:` are the caller's own — `#wings` already
    # built and counted this scope for `@total`; recomputing both here was
    # an identical second `COUNT(*)` on every request (`/simplify`).
    def coverage_lines(active, scope:, total:)
      Painting::FacetVoice::PLATE_FACETS.filter_map do |facet|
        next if active[facet]

        known = scope.where.not(facet => nil).count
        next if total.zero? || known == total

        { facet: facet, label: Painting::FacetVoice::FACET_LABEL.fetch(facet), known: known, total: total }
      end
    end
end
