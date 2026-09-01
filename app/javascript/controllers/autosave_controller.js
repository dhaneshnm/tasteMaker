import { Controller } from "@hotwired/stimulus"

// The reader's own comment (story 0033, replacing the sit gate's draft).
// Mounted ONCE, on the persistent turbo-frame element in `daily/_day.html.erb`
// — Turbo replaces a frame's CHILDREN on every navigation, never its own
// attributes, so this controller survives every swap between the composer,
// the rendered comment, and back again. `hasInputTarget`/`hasStatusTarget`
// guard the parts that only exist in the composer's current content.
//
//   composer ── blur/debounce ──> saved silently, composer stays editable
//            ── Enter (dirty) ──> await save, then reload as a comment
//            ── Enter (clean) ──> reload as a comment, nothing to save
//            ── Enter (blank) ──> the row is deleted server-side, reload
//                                  lands back on an empty composer
//            ── save fails ─────> no reload; the text and focus stay put
//   comment (today only) ── tap ──> reload with ?edit=1, prefilled composer
//
// The day-end ink boundary lives entirely in what the server renders for a
// given painting (today's front-door pick vs. an archived day) — this
// controller never computes a date; it only ever asks for the plain control
// URL or the same URL with `?edit=1`.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = { controlUrl: String, writeUrl: String }

  // Mounted once, on the persistent frame — `connect()` fires only for
  // THIS controller's own lifecycle, never again on the child-content
  // swaps that carry it between composer, comment, and back. `this.saved`
  // has to resync on every one of those swaps too (`turbo:frame-load`
  // fires for each), or a tap-to-edit reopen leaves it stale from before
  // the prefill: a reader who edits, changes nothing, and hits Enter would
  // otherwise read as dirty and fire a needless write.
  connect() {
    this.resync()
    this.onFrameLoad = () => this.resync()
    this.element.addEventListener("turbo:frame-load", this.onFrameLoad)
    this.onFlush = () => this.flush()
    window.addEventListener("pagehide", this.onFlush)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("turbo:frame-load", this.onFrameLoad)
    window.removeEventListener("pagehide", this.onFlush)
  }

  resync() {
    this.saved = this.hasInputTarget ? this.inputTarget.value.trim() : undefined
  }

  changed() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), 800)
  }

  keydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.commit()
  }

  blurred() {
    this.save()
  }

  // Tap own comment (today only — the server never renders this button on
  // an archived day) → reload the frame in edit mode, prefilled.
  edit() {
    this.element.src = `${this.controlUrlValue}?edit=1`
  }

  // The Enter gesture: "set it down." Dirty text saves first; clean text
  // (nothing changed since the last save) skips straight to reload rather
  // than dead-ending on autosave's own no-op guard (eng OV8). A blank body
  // is a real value here — the server destroys the row and the reload lands
  // on an empty composer (eng OV2).
  async commit() {
    clearTimeout(this.timer)
    const body = this.inputTarget.value.trim()
    if (body !== this.saved) {
      const ok = await this.write(body)
      if (!ok) return // failed: composer keeps the text, no swap, silent
      this.saved = body
    }
    this.reload()
  }

  // The silent path: debounce and blur only ever save non-blank drafts.
  // Emptying the field this way does nothing until Enter says so — a
  // reader who deletes their line while still thinking must not have it
  // published-as-deleted by an accidental tab-away.
  async save() {
    clearTimeout(this.timer)
    // Same guard `flush()` already needs: a debounce timer set while the
    // composer was up can still fire after Enter/edit swapped the frame's
    // children out from under it — the target this timer was scheduled
    // for may simply be gone by the time it runs.
    if (!this.hasInputTarget) return
    const body = this.inputTarget.value.trim()
    if (!body || body === this.saved) return
    await this.write(body)
  }

  async write(body) {
    try {
      const resp = await fetch(this.writeUrlValue, {
        method: "POST",
        body: new URLSearchParams({ body, authenticity_token: this.csrfToken() }),
        keepalive: true
      })
      if (resp.ok) {
        this.saved = body
        if (this.hasStatusTarget) this.statusTarget.textContent = this.statusTarget.dataset.savedCopy
      }
      return resp.ok
    } catch {
      return false
    }
  }

  // The page may be going away — sendBeacon survives it. Same silent-draft
  // rule as `save()`: never flushes a blank over an existing line.
  flush() {
    if (!this.hasInputTarget) return
    const body = this.inputTarget.value.trim()
    if (!body || body === this.saved) return
    try {
      navigator.sendBeacon(this.writeUrlValue,
        new URLSearchParams({ body, authenticity_token: this.csrfToken() }))
      this.saved = body
    } catch {}
  }

  // `/` (and the impression frame that lives on it) carries no CSRF meta
  // tag by design — story 0007: minting one would write a session onto a
  // page Thruster caches for every reader. The composer's own `<form>`
  // still gets Rails' usual hidden `authenticity_token` field, because IT
  // is the walled, `no_store` fragment fetched separately — reading it
  // from there is what a real form submission would have sent anyway.
  //
  // No `hasInputTarget` guard: every caller (`write()`, only ever reached
  // through `commit()`/`save()`; `flush()`) already dereferences
  // `inputTarget` or returns early without it first, so by the time this
  // runs the target is guaranteed present.
  csrfToken() {
    return this.inputTarget.closest("form")?.querySelector('[name="authenticity_token"]')?.value
  }

  reload() {
    this.element.src = this.controlUrlValue
  }
}
