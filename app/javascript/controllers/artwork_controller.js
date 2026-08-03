import { Controller } from "@hotwired/stimulus"

// The daily artwork: opens full screen, and steps aside when the image is gone.
//
// Zoom is a modal: focus moves to Close, Tab stays trapped there, Escape or a
// tap anywhere closes it, and focus returns to the artwork. The page behind it
// does not scroll.
export default class extends Controller {
  static targets = ["trigger", "image", "placeholder", "overlay", "close"]

  connect() {
    // An image that failed before Stimulus booted never fires `error` for us.
    if (this.hasImageTarget && this.imageTarget.complete && this.imageTarget.naturalWidth === 0) {
      this.imageFailed()
    }
  }

  disconnect() {
    this.releaseModal()
  }

  open() {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.hidden = false
    document.documentElement.classList.add("zoom-open")
    document.addEventListener("keydown", this.keydown)
    this.closeTarget.focus()
  }

  close() {
    this.releaseModal()
    if (this.hasTriggerTarget) this.triggerTarget.focus()
  }

  // A field, not a method: the same reference has to come off `document` again.
  keydown = (event) => {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    } else if (event.key === "Tab") {
      // One control in the dialog, so the trap is simply: stay on it.
      event.preventDefault()
      this.closeTarget.focus()
    }
  }

  // The museum CDN can 404 on us. Show the note instead of a broken frame.
  imageFailed() {
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = false
  }

  releaseModal() {
    if (this.hasOverlayTarget) this.overlayTarget.hidden = true
    document.documentElement.classList.remove("zoom-open")
    document.removeEventListener("keydown", this.keydown)
  }
}
