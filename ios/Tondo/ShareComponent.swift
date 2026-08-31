import HotwireNative
import UIKit

/// The shell's first bridge component (`decisions/0021`) — hands one
/// painting's image, title/artist and a link back to the app to any share
/// target iOS allows.
///
/// `name` must read exactly `"share"`: it is what the library folds into
/// the WKWebView's User-Agent (`bridge-components: [share]`), which is the
/// same string both `share_controller.js`'s `shouldLoad` gate and
/// `layouts/_head.html.erb`'s reveal script read to decide whether the web
/// button connects and shows at all.
final class ShareComponent: BridgeComponent {
    override class var name: String { "share" }

    override func onReceive(message: Message) {
        guard message.event == "share",
              let payload: SharePayload = message.data(),
              let viewController,
              // Re-entrancy guard (eng review E3): a double-tap sends two
              // messages before the first sheet finishes presenting. A
              // second `present` on top of an already-presented activity
              // controller either throws or silently drops — never two
              // sheets.
              viewController.presentedViewController == nil,
              let shareURL = URL(string: payload.url)
        else { return }

        let imageURL = URL(string: payload.imagePath, relativeTo: currentPageURL)?.absoluteURL

        let activityItems: [Any] = if let imageURL {
            [ payload.text, shareURL, ShareImageItemProvider(shareURL: shareURL, imageURL: imageURL) ]
        } else {
            // No resolvable image path (a malformed payload, not the normal
            // case) — text and link still make a complete share.
            [ payload.text, shareURL ]
        }

        let activityViewController = UIActivityViewController(
            activityItems: activityItems, applicationActivities: nil)

        // iPad presents this as a popover and crashes without an anchor —
        // an iPhone-only app today, but one that still runs on iPad.
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                         y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(activityViewController, animated: true)
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    /// The page the tap came from, not the share target — `payload.url` is
    /// always `root_url`, an address `imagePath` (a relative blob path on
    /// most works) has nothing to do with.
    private var currentPageURL: URL? {
        delegate?.webView?.url
    }
}

private struct SharePayload: Decodable {
    let text: String
    let url: String
    let imagePath: String
}

/// Presents the sheet the instant the reader taps rather than after a
/// download — over cellular a full-resolution museum image is seconds of
/// silence, which reads as a dead button (design review D2). The image
/// arrives inside the already-open sheet instead.
///
/// `UIActivityItemProvider` is an `NSOperation` subclass, and Apple's own
/// docs make `item` a SYNCHRONOUS property the activity controller calls on
/// a background operation queue — blocking here is the documented contract,
/// not a workaround (outside voice C4). On failure or timeout it still has
/// to return `Any`, so it falls back to the share URL: the target app gets
/// a second link instead of a broken attachment, never a stall.
final class ShareImageItemProvider: UIActivityItemProvider, @unchecked Sendable {
    private let shareURL: URL
    private let imageURL: URL

    // Set only while `item` is blocked waiting on it — `cancel()` reaches in
    // to unblock that wait early (code review, adversarial pass). Without
    // this, dismissing the sheet — or backgrounding the app — mid-download
    // left the operation-queue thread parked in `semaphore.wait()` for the
    // full 10s timeout regardless: `UIActivityItemProvider` is an `Operation`
    // subclass and the activity controller calls `cancel()` on it when the
    // sheet closes early, but a synchronous, already-running `item` getter
    // never observes that unless something inside it acts on the call.
    private var task: URLSessionDataTask?

    init(shareURL: URL, imageURL: URL) {
        self.shareURL = shareURL
        self.imageURL = imageURL
        super.init(placeholderItem: shareURL)
    }

    override var item: Any {
        var request = URLRequest(url: imageURL)
        request.timeoutInterval = 10

        let semaphore = DispatchSemaphore(value: 0)
        var result: Any = shareURL

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error == nil, let data, let image = UIImage(data: data) {
                result = image
            }
            semaphore.signal()
        }
        self.task = task
        task.resume()
        semaphore.wait()
        self.task = nil

        return result
    }

    // `cancel()` on the task fires its completion handler promptly (with a
    // cancellation error, so `result` stays the URL fallback) rather than
    // waiting out the timeout — that's what turns the up-to-10s stall into a
    // near-immediate unblock.
    override func cancel() {
        task?.cancel()
        super.cancel()
    }
}
