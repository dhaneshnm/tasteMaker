import { Controller } from "@hotwired/stimulus"

// Blurb length is the feature: long enough to teach, short enough for a
// three-minute morning. This nudges, it never blocks.
export default class extends Controller {
  static targets = ["input", "output"]
  static values = { min: Number, max: Number }

  connect() {
    this.count()
  }

  count() {
    const words = this.inputTarget.value.split(/\s+/).filter(Boolean).length
    const inRange = words >= this.minValue && words <= this.maxValue

    this.outputTarget.textContent = words === 0
      ? `Aim for ${this.minValue}–${this.maxValue} words`
      : `${words} words${inRange ? "" : ` — aim for ${this.minValue}–${this.maxValue}`}`
    this.outputTarget.classList.toggle("is-off-target", words > 0 && !inRange)
  }
}
