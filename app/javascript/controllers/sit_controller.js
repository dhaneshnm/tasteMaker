import { Controller } from "@hotwired/stimulus"

// The conversation thread (story 0033, replacing the sit gate). Front door
// only — the archive and preview render the same markup permanently open,
// with a server-assigned frame src and no Stimulus at all (decisions/0023).
//
//   connect ──> frame.src = control (composer/comment/hint)
//      │        thread visible? ──> shown beacon (once/day, key `shown`)
//      │
//   bubble tap ──> toggle .conv, day-scoped memory (key `conv`),
//      │           shown beacon fires on an OPEN that hadn't fired yet today
//      │
//   pin tap (native <details>, no JS required to open it) ──>
//      describedby swap (daily-note ↔ sit-prompt), completed beacon on
//      first open of the day (key `pin`)
//
// The reader's own comment (composer, edit, commit) is `autosave_controller`'s
// job entirely — it owns the frame's fetched content start to finish and
// needs nothing from this controller.
export default class extends Controller {
  static targets = ["bubble", "conv", "slot"]
  static values = { date: String, controlUrl: String, shownUrl: String, completedUrl: String }

  connect() {
    this.slotTarget.src = this.controlUrlValue
    this.syncBubble()
    if (!this.convTarget.hidden) this.markShown()
  }

  toggleConv() {
    const opening = this.convTarget.hidden
    this.convTarget.hidden = !opening
    this.syncBubble()
    try {
      if (this.convTarget.hidden) localStorage.setItem("conv", this.dateValue)
      else localStorage.removeItem("conv")
    } catch (e) {}
    if (opening) this.markShown()
  }

  // Wired `toggle->sit#pinToggled` directly on `.cmt__pin` — the native
  // `toggle` event does not bubble, so the action lives on the details
  // itself rather than delegated from this controller's own element.
  pinToggled(event) {
    const details = event.target
    this.plateImg()?.setAttribute("aria-describedby", details.open ? "daily-note" : "sit-prompt")
    if (details.open && !this.dedupe("pin")) this.beacon(this.completedUrlValue)
  }

  // Fill IS the state, the same mechanism Keep's own glyph uses (a `fill`
  // attribute on the `<svg>` — `favorites/_keep_glyph.html.erb`) rather
  // than a parallel CSS rule reacting to the aria attribute. Keep sets it
  // server-side because its state only ever changes on a frame round trip;
  // the bubble sets it here because its state changes instantly, with no
  // round trip to render from — same idiom, the only difference the toggle
  // speed forces.
  syncBubble() {
    const open = !this.convTarget.hidden
    this.bubbleTarget.setAttribute("aria-expanded", String(open))
    this.bubbleTarget.setAttribute("aria-label", open ? "Hide the notes" : "Read the notes")
    this.bubbleTarget.querySelector("svg")?.setAttribute("fill", open ? "currentColor" : "none")
  }

  markShown() {
    if (this.dedupe("shown")) return
    this.beacon(this.shownUrlValue)
  }

  // One fixed key per fact, each valued with today's served date — never
  // read as a boolean, so a stale entry from a prior date always reads as
  // "not yet today" rather than needing its own cleanup pass.
  dedupe(key) {
    try {
      if (localStorage.getItem(key) === this.dateValue) return true
      localStorage.setItem(key, this.dateValue)
      return false
    } catch (e) {
      // Storage blocked: dedupe can't hold, so every open re-fires. Accepted
      // — the same stance 0032 shipped with for a spoofable, identity-free tally.
      return false
    }
  }

  plateImg() {
    return document.querySelector(".plate__img")
  }

  beacon(url) {
    try { navigator.sendBeacon(url) } catch {}
  }
}
