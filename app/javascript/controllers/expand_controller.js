import { Controller } from "@hotwired/stimulus"

// Instagram-style "More" toggle for long wall-label descriptions.
// The button stays hidden unless the clamped text actually overflows.
export default class extends Controller {
  static targets = ["text", "button"]

  connect() {
    requestAnimationFrame(() => this.measure())

    // Inside a closed <details> (the sit gate, story 0032) nothing has
    // layout: scrollHeight and clientHeight are both 0 at connect, so the
    // measure above decides "no overflow" and the More button would stay
    // hidden forever on every museum-fallback day (eng OV4). Re-measure when
    // an enclosing details opens; measuring an already-visible text twice is
    // harmless, so this needs no gate-awareness.
    this.enclosing = this.element.closest("details")
    if (this.enclosing) {
      this.onToggle = () => { if (this.enclosing.open) this.measure() }
      this.enclosing.addEventListener("toggle", this.onToggle)
    }
  }

  disconnect() {
    this.enclosing?.removeEventListener("toggle", this.onToggle)
  }

  measure() {
    const el = this.textTarget
    if (el.scrollHeight > el.clientHeight + 2) {
      this.buttonTarget.hidden = false
    }
  }

  toggle() {
    const expanded = this.element.classList.toggle("expanded")
    this.buttonTarget.textContent = expanded ? "Less" : "More"
  }
}
