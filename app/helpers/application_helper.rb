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
  # `locked:` is story 0017's addition, and it is a THIRD reason a destination
  # loses its link — distinct from `current`, and deliberately not merged with
  # it:
  #
  #   current   you are standing here          --ink-dim, aria-current="page"
  #   locked    you cannot get in from here    --ink-dim, no aria-current
  #
  # It exists for one page. `/you` is where `require_reader` bounces every
  # cookieless visitor, and three of the four destinations are behind the wall
  # that just bounced them — so tapping Days from there lands back on `/you`,
  # and the row becomes a set of controls that visibly do nothing. Marking them
  # the way the compass already marks the current page says "gated", not
  # "broken", using a treatment the reader has seen since their first screen.
  #
  # ONLY `/you` MAY PASS THIS. The compass renders inside `/`, which is
  # `Cache-Control: public` behind Thruster and must be byte-identical for every
  # reader (story 0007). A compass that varied by identity there would put
  # per-visitor markup into a shared cache. `/you` is `private, no-store`, which
  # is what makes it the one safe place for this.
  def compass_destinations(here, locked: [])
    unless here.nil? || COMPASS_KEYS.include?(here)
      raise ArgumentError,
        "unknown compass key #{here.inspect} — expected nil or one of #{COMPASS_KEYS.inspect}"
    end

    unknown = locked - COMPASS_KEYS
    if unknown.any?
      raise ArgumentError,
        "unknown locked compass key(s) #{unknown.inspect} — expected a subset of #{COMPASS_KEYS.inspect}"
    end

    COMPASS.map do |key, label, route|
      { key: key, label: label, path: public_send(route),
        current: key == here, locked: locked.include?(key) }
    end
  end

  # The three destinations a reader with no identity cannot reach. Derived from
  # the wall's own rule rather than typed out again: `Today` is the only surface
  # that skips `require_reader`, so it is the only one that stays a link.
  #
  # Returns [] for an identified reader, which is what keeps this from becoming
  # a second definition of "signed in" scattered through the views.
  def walled_compass_keys
    COMPASS_KEYS - [ :today ]
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
