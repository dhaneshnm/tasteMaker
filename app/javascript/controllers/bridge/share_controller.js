import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// The tap that hands one painting to any app iOS allows (story 0031).
//
// Extends the package's own `BridgeComponent`, not Stimulus's bare
// `Controller`. Its `static shouldLoad` reads the same `navigator.userAgent`
// string `layouts/_head.html.erb`'s reveal script does — so this controller
// never even CONNECTS outside a shell whose native side registered a
// "share" component. A tap on the (already-hidden) button in a plain
// browser lands on nothing: no controller attached, no action fires.
export default class extends BridgeComponent {
  static component = "share"
  static values = { text: String, url: String, imagePath: String }

  share() {
    this.send("share", {
      text: this.textValue,
      url: this.urlValue,
      imagePath: this.imagePathValue
    })
  }
}
