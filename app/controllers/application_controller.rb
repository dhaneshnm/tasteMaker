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

  # The wall (story 0015, retargeted by story 0017). One guard, two keys:
  #
  #   request ──> require_reader ──┬── session[:user_id] → User row?   pass
  #                                ├── signed device cookie → Device?  pass
  #                                └── neither → 303 to /you
  #
  # 303, not 302: the wall bounces POSTs too (a signed-out keep tap), and Turbo
  # re-issues the method on a 302.
  #
  # The target used to be `/#signin` — an anchor onto a lazily-loaded fragment
  # at the foot of the landing page. Story 0017 deleted that fragment and gave
  # the sign-in doors a room of their own, so the bounce lands on a whole page
  # that can explain itself instead of on an anchor that had to be scrolled to.
  # `/you` is unwalled for exactly this reason: it is where a reader with no
  # identity is sent, so it cannot require one.
  #
  # Skips live on the controllers themselves: the landing page (daily#show),
  # errors, sessions, device registrations, and admin (whose key is basic auth,
  # unchanged). Active Storage never passes through here — its controllers do
  # not inherit this one — and must not: the landing artwork is for everyone.
  # Blob URLs are signed capability URLs; that is their whole protection, and
  # it is named in the plan rather than discovered later (eng review A3).
  before_action :require_reader

  # And so does a change to the templates themselves, which is the general case
  # the two lines above are each a special case of.
  #
  # The importmap etag covers JavaScript. The stylesheet etag covers CSS. Both
  # were added after a specific bug. Neither covers the third input the page is
  # built from: the text of the `.erb` files. `/` and `/days` key their ETags on
  # model rows, so editing a masthead, a `<title>`, or any other string ships a
  # new page behind an unchanged ETag — every browser holding the old HTML
  # revalidates into a 304 and keeps the old words, and every reload does it
  # again. Renaming this product to Tondo (story 0011) would have been exactly
  # that, on every screen at once.
  #
  # `config.x.revision` is written per image build by the Dockerfile, so a
  # deploy busts every conditional GET once and then they settle back into 304s.
  # A template digest would be more precise, but dependency tracking through
  # `render` is implicit and a missed partial fails silently in the same
  # direction as the bug — this value cannot miss anything.
  etag { Rails.application.config.x.revision }

  private
    def require_reader
      return if identified?

      # A frame WRITE cannot follow the bounce usefully: Turbo would fetch
      # `/`, find no frame matching (say) `keep_42`, and swap in "Content
      # missing" — a silent hole where the habit mechanic was, for the reader
      # whose identity died mid-page (signed out elsewhere, device revoked).
      # Answer those in kind: a matching frame whose one link breaks out to
      # the corner (code review F5).
      #
      # Frame GETs never reach here any more. `favorites#control` skips the wall
      # and answers the null state itself — the keep frame on `/` is eager, and
      # bouncing it wrote "Content missing" over the resting mark. The claim
      # that used to sit here, that a failed frame load keeps its default
      # content, was only ever true because the bounce happened to land on a
      # page carrying the same frame.
      if turbo_frame_request? && !request.get?
        render html: helpers.turbo_frame_tag(request.headers["Turbo-Frame"]) {
          helpers.link_to "Sign in", corner_path,
            class: "caps-link", data: { turbo_frame: "_top" }
        }, status: :unauthorized
      else
        redirect_to corner_path, status: :see_other
      end
    end

    def current_user
      return @current_user if defined?(@current_user)
      # Assigns nil too — a guarded assignment would never latch the
      # memoization for the common (device) case.
      @current_user = session[:user_id] && User.find_by(id: session[:user_id])
    end
    helper_method :current_user

    # Memoizes the row, not just a digest: exists? plus a later last_seen_at
    # touch would be two queries; find_by is the same one indexed read and
    # hands the row to whoever needs it (eng review, Codex).
    def current_device
      return @current_device if defined?(@current_device)
      token = cookies.signed[:device]
      @current_device = token.present? ? Device.find_by(token_digest: Device.digest(token))&.tap(&:note_seen) : nil
    end
    # Exposed to views for the same reason `current_user` is, and only since
    # story 0016: the collection page has to offer the device its exit door, and
    # "which identity is this" is the question that decides which door to draw.
    # Already memoized, so a view calling it costs nothing.
    helper_method :current_device

    # Which world this reader keeps in (story 0015; moved here by story 0017).
    # A signed-in web reader's rows carry user_id; a device's rows carry the
    # digest of its registered Keychain UUID.
    #
    #   current_user  ──> Favorite.owned_by(user)
    #   current_device ─> Favorite.collected_by(digest)
    #   neither ───────> caller must not ask — see the guard below
    #
    # These lived in FavoritesController until `/you` needed the same question
    # answered for its two delete confirms, which both name a work count. Two
    # copies of "this reader's kept works" is one copy too many: the day they
    # drift, `/you` shows a number that disagrees with `/collection` on a dialog
    # for an irreversible delete.
    #
    # `identified?` exists because the wall no longer guarantees an identity for
    # every caller. `CornersController` skips the wall on purpose — it is where
    # a reader with no identity is sent — so it is the first caller that can
    # reach here with neither key, and `current_device.token_digest` on nil is
    # a 500 on the one page a bounced visitor lands on.
    def identified?
      current_user || current_device
    end

    def reader_favorites
      current_user ? Favorite.owned_by(current_user) : Favorite.collected_by(current_device.token_digest)
    end

    def reader_identity_attributes
      current_user ? { user: current_user } : { collector_digest: current_device.token_digest }
    end

    # Private and uncacheable, always. `Vary: Cookie` is belt to the no-store
    # braces: nothing should store these, and nothing should reuse one reader's
    # copy for another if it does. Shared by every per-visitor endpoint —
    # favorites and sessions both — so a new one cannot ship storable
    # per-visitor responses by hand-rolling its own headers.
    def no_store
      response.cache_control.replace(private: true, no_store: true)
      response.headers["Vary"] = "Cookie"
    end

    # The shell appends "Tondo iOS/<version>" to WKWebView's user agent
    # (AppDelegate's applicationUserAgentPrefix). The sign-in fragment reads
    # this so an UNREGISTERED shell — first launch, registration failed or
    # still in flight — degrades to art-plus-nothing, never to Google buttons
    # inside the app (eng review, Codex). One constant, referenced by the
    # tests too, so a rename in the shell fails loudly instead of silently
    # showing login UI in the app.
    NATIVE_UA_TOKEN = "Tondo iOS".freeze

    def native_shell?
      request.user_agent.to_s.include?(NATIVE_UA_TOKEN)
    end

    # A gated page that still revalidates: private (Thruster must not hold a
    # gated body — a shared cache entry outlives a sign-out), no-cache (every
    # request revalidates), expressed via `extras` because Rails' no_cache
    # header branch honors :public and :extras but ignores :private. Sibling
    # of `no_store` above, for the pages that keep their ETags.
    def private_revalidate
      response.cache_control.replace(no_cache: true, extras: [ "private" ])
    end
end
