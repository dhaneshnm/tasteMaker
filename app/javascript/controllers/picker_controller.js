import { Controller } from "@hotwired/stimulus"

// Choosing a painting by title alone is guesswork; show the picture.
export default class extends Controller {
  static targets = ["select", "image"]

  connect() {
    this.show()
  }

  show() {
    const source = this.selectTarget.selectedOptions[0]?.dataset.thumb

    if (source) {
      this.imageTarget.src = source
      this.imageTarget.hidden = false
    } else {
      this.imageTarget.removeAttribute("src")
      this.imageTarget.hidden = true
    }
  }
}
