import { Controller } from "@hotwired/stimulus"

// The sit gate (story 0032): the note starts folded behind a quiet
// invitation; a soft minute later the invitation becomes the ready line and
// the reveal control earns its gold. The reveal is ALWAYS the reader's own
// tap — this controller never opens the details itself (design D3), and the
// gate never locks: the summary opens the note at any moment.
//
//   connect (closed) ──> shown beacon ──> timer (visibility-paused)
//        │                                   │
//        │ reader taps early                 │ minute completes
//        ▼                                   ▼
//   finalize: mark day,                 ready state: copy swap, gold,
//   no field this visit                 aria-live line, frame gets its src
//   (foreclosure is intended, D5)       (the ONLY place src is assigned)
//
// Already-revealed revisits arrive with the details pre-opened by the
// inline pre-paint script in the view — connect sees `open`, finalizes, and
// never arms a timer or fires a beacon. The zoom overlay deliberately does
// NOT pause the timer: zooming is looking (design F15b).
export default class extends Controller {
  static targets = ["details", "summary", "status", "slot"]
  static values = {
    duration: Number, date: String, controlUrl: String,
    shownUrl: String, completedUrl: String, readyCopy: String
  }

  connect() {
    this.finished = false
    if (this.detailsTarget.open) { this.finalize(); return }

    this.beacon(this.shownUrlValue)
    // Guard found by live QA: a missing/garbled duration value (a stale
    // server boot once rendered "{}") multiplies to NaN and setTimeout(NaN)
    // fires IMMEDIATELY — an instant ready state, the opposite of a sit.
    // A gate that cannot know its minute sits the full default.
    const seconds = this.durationValue > 0 ? this.durationValue : 60
    this.remaining = seconds * 1000
    this.startedAt = Date.now()
    this.arm()
    // A backgrounded tab is not looking: bank the elapsed time on hide,
    // resume the balance on return.
    this.onVisibility = () => this.visibilityChanged()
    document.addEventListener("visibilitychange", this.onVisibility)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("visibilitychange", this.onVisibility)
  }

  // Wired as `toggle->sit#toggled` on the details element. Opening — at any
  // time, by any reader — cancels the minute silently and marks the day; no
  // "the minute is up" residue may appear after the reader already chose
  // (design F15a). There is no close branch: the summary disappears once
  // the details opens (the revealed page is the old page — see the CSS),
  // so a revealed note cannot be re-folded except by tomorrow's date.
  toggled() {
    if (!this.detailsTarget.open) return
    clearTimeout(this.timer)
    try { localStorage.setItem("sit", this.dateValue) } catch {}
    this.finalize()
  }

  arm() {
    this.timer = setTimeout(() => this.complete(), this.remaining)
  }

  visibilityChanged() {
    if (this.finished) return
    if (document.hidden) {
      clearTimeout(this.timer)
      this.remaining -= Date.now() - this.startedAt
    } else if (!this.detailsTarget.open) {
      this.startedAt = Date.now()
      this.arm()
    }
  }

  complete() {
    if (this.finished || this.detailsTarget.open) return
    this.finished = true
    this.beacon(this.completedUrlValue)
    this.element.classList.add("sit--ready")
    this.summaryTarget.textContent = this.readyCopyValue
    // The summary's own text change announces nothing; this line does.
    this.statusTarget.textContent = this.readyCopyValue
    // The impression frame ships inert — no src, no request, for anyone who
    // never reaches this line (eng E3). Assigning src here is what asks the
    // server whether this reader gets a field at all.
    this.slotTarget.src = this.controlUrlValue
  }

  finalize() {
    this.finished = true
    clearTimeout(this.timer)
    this.element.classList.add("sit--revealed")
    this.statusTarget.textContent = ""
    // While folded the artwork was described by the invitation, so a
    // screen reader never hears the note pre-reveal (eng OV5); the reveal
    // hands the description back to the note itself.
    this.plateImg()?.setAttribute("aria-describedby", "daily-note")
  }

  plateImg() {
    return document.querySelector(".plate__img")
  }

  beacon(url) {
    // Identity-free tally (eng OV6); sendBeacon so a tab closing mid-flight
    // still counts. Failure is silence — the tally is never worth an error.
    try { navigator.sendBeacon(url) } catch {}
  }
}
