class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # And so does a change to the stylesheet. Rails ships the importmap half of
  # this and nothing for CSS, which left a hole: `/` and `/days` key their
  # ETags on model data (`fresh_when`/`stale?` in DailyController and
  # DaysController), so shipping a CSS change moved the asset digest and left
  # the ETag identical. Every browser holding the previous HTML revalidated,
  # got a 304, and kept markup pointing at `/assets/application-<old>.css` — a
  # URL that no longer resolves. The page then rendered with no styles at all,
  # indefinitely, because each reload revalidated back into the same 304.
  #
  # `app_stylesheets_paths` is what `stylesheet_link_tag :app` in
  # `layouts/_head.html.erb` expands to, so this covers exactly the sheets the
  # page actually links — including any second one added later.
  #
  # No `request.format.html?` guard, deliberately, even though Rails' importmap
  # version has one. A client sending `Accept: */*` has a format of `*/*`, not
  # html, so the guard would hand exactly that client the stale-forever 304 this
  # exists to prevent — and make the ETag for one URL depend on a request header
  # that does not change the body. The cost of dropping it is that a CSS change
  # also invalidates any non-HTML conditional GET: one extra fetch, once.
  etag { helpers.app_stylesheets_paths.map { |sheet| helpers.stylesheet_path(sheet) } }
end
