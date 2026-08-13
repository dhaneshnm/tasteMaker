module ApplicationHelper
  # Where a painting's picture comes from: the locally stored copy when we have
  # one, otherwise the museum CDN. One rule, one place.
  #
  # `size:` asks for a square-bounded variant instead of the full image — the
  # archive list draws thumbnails, and an 800px JPEG at 112px, thirty times, is
  # about 20 MB on a phone.
  #
  # The rescue is narrow and it logs. It catches the blob refusing to be varied at
  # all (wrong content type, missing blob); actual vips failures happen later,
  # when the variant is resolved, and surface as a broken image, which the row's
  # collapsed thumbnail already handles. A bare rescue plus a working fallback
  # would let a wholly broken pipeline look healthy while quietly serving
  # full-size images forever.
  def artwork_src(painting, size: nil)
    return painting.image_url_800 unless painting.image.attached?
    return url_for(painting.image) if size.nil?
    # Asked for a thumbnail on a box with no image processor: the museum's 800px
    # copy is the smaller of the two things we can serve. The locally stored
    # original runs to 750 KB, and a page of them is the 20 MB phone load this
    # size argument exists to prevent.
    return painting.image_url_800.presence || url_for(painting.image) unless resizing_available?

    painting.image.variant(resize_to_limit: [ size, size ])
  rescue ActiveStorage::Error => e
    Rails.logger.warn("[artwork_src] variant failed for painting #{painting.id}: #{e.class}")
    painting.image_url_800
  end

  # Where a day lives. One day has one address: the pick the front door is
  # showing is `/`, every other published day is `/days/:date`. Written once so
  # a link never points at a URL that immediately 301s — `DaysController#show`
  # enforces the same rule from the other side.
  def day_link_path(pick, current)
    pick == current ? root_path : day_path(pick.scheduled_on.iso8601)
  end

  # The four surfaces a reader can be on, in the order the compass shows them:
  # today first because it is the ritual, the gallery last because it is the
  # side trip. One word each — `.caps-link` is 0.78rem at 0.2em tracking, and
  # measured at 375px four one-word labels fit on one row while four two-word
  # labels wrap to two. Every wrapped row costs 44px above the artwork
  # (`DESIGN.md` rule 9), so the copy length is a layout constraint, not a
  # matter of taste. `specs/0012-getting-around/plan.md` has the measurements.
  #
  # The third element is the *name* of a route helper, not a path. Route
  # helpers are request-context methods, so calling them while building a
  # frozen constant would either fail or freeze one request's idea of a URL
  # into the class.
  COMPASS = [
    [ :today,      "Today",   :root_path ],
    [ :days,       "Days",    :days_path ],
    [ :collection, "Kept",    :collection_path ],
    [ :gallery,    "Gallery", :feed_path ]
  ].freeze

  COMPASS_KEYS = COMPASS.map(&:first).freeze

  # `here` is a tri-state, and the middle state is the interesting one:
  #
  #   nil          four links, nothing marked      /days/:date, /404
  #   a key        that one is marked and unlinked  /, /days, /collection, /feed
  #   anything else raises
  #
  # `/days/:date` passes nil on purpose. An archived day is a *member* of the
  # archive, not the archive itself — marking `Days` as current there would
  # unlink the only route from one old day back to the list, since `days/_walk`
  # offers previous, next and today and nothing else. The 404 is the same
  # shape: it is not one of the four surfaces.
  #
  # It raises rather than silently rendering four links, because a typo in a
  # `here:` local would otherwise look exactly like a page that meant to pass
  # nil, and the reader would lose their "you are here" with nothing failing.
  def compass_destinations(here)
    unless here.nil? || COMPASS_KEYS.include?(here)
      raise ArgumentError,
        "unknown compass key #{here.inspect} — expected nil or one of #{COMPASS_KEYS.inspect}"
    end

    COMPASS.map do |key, label, route|
      { key: key, label: label, path: public_send(route), current: key == here }
    end
  end

  # Resizing needs libvips or ImageMagick on the box, and this machine has
  # neither — see the analyzer note in `config/application.rb`. Asking for a
  # variant anyway does not raise here: it raises later, inside Active Storage's
  # redirect controller, so every thumbnail 500s and the rescue above never sees
  # it. Ask whether resizing is possible before requesting it.
  def resizing_available?
    ActiveStorage.variant_transformer.present?
  end
end
