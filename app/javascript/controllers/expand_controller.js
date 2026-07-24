import { Controller } from "@hotwired/stimulus"

// Instagram-style "More" toggle for long wall-label descriptions.
// The button stays hidden unless the clamped text actually overflows.
export default class extends Controller {
  static targets = ["text", "button"]

  connect() {
    requestAnimationFrame(() => {
      const el = this.textTarget
      if (el.scrollHeight > el.clientHeight + 2) {
        this.buttonTarget.hidden = false
      }
    })
  }

  toggle() {
    const expanded = this.element.classList.toggle("expanded")
    this.buttonTarget.textContent = expanded ? "Less" : "More"
  }
}
