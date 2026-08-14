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
  static targets = ["image", "overlay", "close", "railZoom"]

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
    const artwork = this.plateFor(trigger)
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

  // `.plate__zoom` wraps its own image, so the trigger contains it. The rail's
  // zoom button (story 0014) sits beside the plate rather than around it, so it
  // does not — it falls back to this scope's single plate.
  //
  // The fallback is safe because the rail only renders on the screens whose job
  // is one artwork. `/feed` has ten plates inside one controller scope and no
  // rail at all, so the first branch always wins there and this never guesses.
  plateFor(trigger) {
    return trigger.querySelector(".plate__img") ?? this.element.querySelector(".plate__img")
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

    // The rail's zoom button is outside `.plate`, so hiding the plate's trigger
    // does not reach it — it would survive and open an empty overlay. Guarded,
    // because `rest()` also runs for feed images and a bare `railZoomTarget`
    // access throws on a page that has no rail.
    //
    // Only on the single-artwork screens, which is the only place a rail exists
    // and therefore the only place "the plate that failed" and "the plate the
    // rail points at" are the same plate.
    if (this.hasRailZoomTarget) this.railZoomTarget.hidden = true
  }

  releaseModal() {
    if (this.hasOverlayTarget) this.overlayTarget.hidden = true
    document.documentElement.classList.remove("zoom-open")
    document.removeEventListener("keydown", this.keydown)
  }
}
