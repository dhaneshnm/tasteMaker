import { Controller } from "@hotwired/stimulus"

// Autosave for the prompt answer (story 0032, redesigned 2026-09-01).
// No Save button, by owner decision: the line is a DRAFT that follows the
// reader's typing — debounced writes, an immediate write on Enter or blur,
// a keepalive flush when the sit ends (the reveal, or the tab going away).
// The only acknowledgment is the SAVED whisper; failure is silence and the
// next keystroke's retry — an error banner mid-looking would cost more
// than a lost draft.
//
// Sits on the form inside the impression frame. The form has no submit
// button and Turbo is off; every save is a bare fetch of the form's own
// action, so the field never re-renders and never loses focus mid-word.
export default class extends Controller {
  static targets = ["input", "status"]

  connect() {
    this.saved = this.inputTarget.value.trim()
    this.onFlush = () => this.save({ flush: true })
    document.addEventListener("sit:flush", this.onFlush)
    window.addEventListener("pagehide", this.onFlush)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("sit:flush", this.onFlush)
    window.removeEventListener("pagehide", this.onFlush)
  }

  changed() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), 800)
  }

  keydown(event) {
    // A one-line field: Enter means "set it down", never submit-the-form
    // (a form submit would Turbo-swap the frame out from under the caret).
    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    }
  }

  blurred() { this.save() }

  async save({ flush = false } = {}) {
    clearTimeout(this.timer)
    const body = this.inputTarget.value.trim()
    if (!body || body === this.saved) return

    const data = new FormData(this.element)
    if (flush) {
      // The page may be going away — sendBeacon survives it.
      try { navigator.sendBeacon(this.element.action, data) } catch {}
      this.saved = body
      return
    }
    try {
      const resp = await fetch(this.element.action, {
        method: "POST", body: data, keepalive: true
      })
      if (resp.ok) {
        this.saved = body
        this.statusTarget.textContent = this.statusTarget.dataset.savedCopy
      }
    } catch {}
  }
}
