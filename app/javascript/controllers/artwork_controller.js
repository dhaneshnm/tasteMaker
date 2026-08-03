import { Controller } from "@hotwired/stimulus"

// The artworks on a page, and the one overlay they all open into.
//
// One artwork on the daily page, a hundred in the archive: the overlay is a
// page-level singleton whose src is filled in on open, because a copy per work
// would put a hidden full-size <img src> next to every one of them, and the
// browser fetches those.
//
// Zoom is a modal: focus moves to Close, Tab stays trapped there, Escape or a
// tap anywhere closes it, and focus returns to the artwork that was tapped. The
// page behind it does not scroll.
export default class extends Controller {
  static targets = ["image", "overlay", "close"]

  opener = null

  connect() {
    // An image that failed before Stimulus booted never fires `error` for us.
    // Works that arrive later with infinite scroll load after this point, so
    // they fire it normally.
    this.element.querySelectorAll(".plate__img").forEach((image) => {
      if (image.complete && image.naturalWidth === 0) this.rest(image)
    })
  }

  disconnect() {
    this.releaseModal()
  }

  open(event) {
    if (!this.hasOverlayTarget) return

    const trigger = event.currentTarget
    const artwork = trigger.querySelector(".plate__img")
    if (!artwork?.currentSrc) return

    this.opener = trigger
    this.imageTarget.src = artwork.currentSrc
    this.imageTarget.alt = artwork.alt
    this.overlayTarget.setAttribute("aria-label", `${trigger.dataset.artworkTitle}, full screen`)

    this.overlayTarget.hidden = false
    document.documentElement.classList.add("zoom-open")
    document.addEventListener("keydown", this.keydown)
    this.closeTarget.focus()
  }

  close() {
    this.releaseModal()
    if (this.opener?.isConnected) this.opener.focus()
    this.opener = null
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
  imageFailed(event) {
    this.rest(event.target)
  }

  // Scoped to the one artwork that failed: the archive has a hundred of them,
  // and a placeholder must not stay tappable.
  rest(image) {
    const plate = image.closest(".plate")
    if (!plate) return

    const trigger = plate.querySelector(".plate__zoom")
    if (trigger) trigger.hidden = true
    plate.querySelector(".plate__resting").hidden = false
  }

  releaseModal() {
    if (this.hasOverlayTarget) this.overlayTarget.hidden = true
    document.documentElement.classList.remove("zoom-open")
    document.removeEventListener("keydown", this.keydown)
  }
}
