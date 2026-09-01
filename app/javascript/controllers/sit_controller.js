import { Controller } from "@hotwired/stimulus"

// The sit gate, prompt form (story 0032, redesigned 2026-09-01): the day's
// looking prompt and the answer field greet the reader at once; the note
// waits behind one always-live READ THE NOTE control. No timer, no staged
// states — the prompt is the scaffold, the skip is first-class.
//
//   connect ──> frame.src = control (the field, or the sign-in hint)
//      │        shown beacon (folded opens only)
//      │ reader taps READ THE NOTE — any time
//      ▼
//   toggled: revealed beacon (first reveal of the day), localStorage mark,
//   flush the draft (sit:flush → autosave's keepalive write), then the
//   frame reloads with after=reveal — the field becomes the answer,
//   read-only; the draft became ink by being read past (D6 as amended).
//
// Already-revealed revisits arrive pre-opened by the inline pre-paint
// script; connect sees `open` and asks the frame for the answer directly.
export default class extends Controller {
  static targets = ["details", "slot"]
  static values = { date: String, controlUrl: String, shownUrl: String, revealedUrl: String }

  connect() {
    // The frame ships inert — src is assigned here, once, to the variant
    // this visit needs. One fetch per open, the Keep frame's own cost; a
    // no-JS visit fetches nothing and the native details still opens.
    if (this.detailsTarget.open) {
      this.slotTarget.src = this.afterRevealUrl()
      this.plateImg()?.setAttribute("aria-describedby", "daily-note")
    } else {
      this.slotTarget.src = this.controlUrlValue
      this.beacon(this.shownUrlValue)
    }
  }

  // Wired as `toggle->sit#toggled` on the details element. There is no
  // close branch: the summary disappears once open (see the CSS) — a
  // revealed note refolds only with tomorrow's date.
  toggled() {
    if (!this.detailsTarget.open) return
    try {
      if (localStorage.getItem("sit") !== this.dateValue) {
        this.beacon(this.revealedUrlValue)
      }
      localStorage.setItem("sit", this.dateValue)
    } catch (e) {
      this.beacon(this.revealedUrlValue)
    }
    this.element.classList.add("sit--revealed")
    this.plateImg()?.setAttribute("aria-describedby", "daily-note")
    // Let the draft land before the frame trades the field for the answer:
    // sit:flush triggers autosave's keepalive write; 350ms rides under the
    // unfold fade. A draft that still misses the swap shows on the next
    // visit — never lost, only late.
    document.dispatchEvent(new CustomEvent("sit:flush"))
    setTimeout(() => { this.slotTarget.src = this.afterRevealUrl() }, 350)
  }

  afterRevealUrl() {
    return `${this.controlUrlValue}?after=reveal`
  }

  plateImg() {
    return document.querySelector(".plate__img")
  }

  beacon(url) {
    // Identity-free tally: shown = gates displayed, revealed = notes opened
    // (first of the day). Failure is silence — never worth an error.
    try { navigator.sendBeacon(url) } catch {}
  }
}
