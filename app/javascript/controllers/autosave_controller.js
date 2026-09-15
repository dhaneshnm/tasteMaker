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
  // resyncs through the target callbacks instead: `inputTargetConnected`
  // runs synchronously the moment the composer's field enters the DOM,
  // and `inputTargetDisconnected` clears it when the comment replaces the
  // composer. (An earlier `turbo:frame-load` listener did this too late —
  // Turbo fires it two repaints after the swap, and a reader (or a test)
  // could clear the prefilled field inside that window, after which the
  // late resync read the emptied field as "already saved" and Enter
  // never wrote the deletion.)
  connect() {
    this.onFlush = () => this.flush()
    window.addEventListener("pagehide", this.onFlush)
  }

  disconnect() {
    clearTimeout(this.timer)
    window.removeEventListener("pagehide", this.onFlush)
  }

  // Tap-to-edit lands the reader in the field, caret after the last word —
  // not staring at a prefilled line they then have to tap into and hunt
  // through (owner report, 2026-09-15). Only the `?edit=1` reload focuses:
  // the day's first composer arrives with the page and must never steal
  // focus, scroll, or a phone keyboard.
  inputTargetConnected() {
    this.resync()
    if (!this.element.src?.includes("edit=1")) return
    const el = this.inputTarget
    el.focus()
    el.setSelectionRange(el.value.length, el.value.length)
  }

  inputTargetDisconnected() {
    this.saved = undefined
  }

  resync() {
    this.saved = this.hasInputTarget ? this.inputTarget.value.trim() : undefined
    this.grow()
    this.count() // a prefilled edit at the limit says so before the first keystroke
  }

  changed() {
    this.grow()
    this.count()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), 800)
  }

  // The 280 is a hard maxlength, and a full field silently drops every
  // further keystroke — which reads as "typing is broken" (owner, on a
  // field padded to the limit). The whisper names it from 40 characters
  // out; before that it stays the empty/Saved line it always was.
  count() {
    if (!this.hasInputTarget || !this.hasStatusTarget) return
    const max = Number(this.inputTarget.maxLength)
    if (!(max > 0)) return
    const left = max - this.inputTarget.value.length
    if (left > 40) return
    this.statusTarget.textContent = left === 0 ? `${max} · full` : `${left} left`
  }

  // The composer is a one-row textarea that must show every word: reset
  // to auto so a deletion can shrink it, then size to the text. Browsers
  // with `field-sizing: content` do this in CSS; the measure is harmless
  // there and the whole fix elsewhere (Safari, as of this writing).
  grow() {
    if (!this.hasInputTarget) return
    const el = this.inputTarget
    el.style.height = "auto"
    // border-box: the set height must cover the hairline too, or the last
    // row sits one pixel under the border and scrolls.
    el.style.height = `${el.scrollHeight + el.offsetHeight - el.clientHeight}px`
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
        this.count() // a near-limit count outranks "Saved" — keep it showing
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
