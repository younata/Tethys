import WebKit
import rNews

class FakeFeedFinder: FeedFinder {

    var didAttemptToFindFeed: Bool = false
    var findFeedCallback: [String] -> Void = {_ in }
    func findUnknownFeedInCurrentWebView(webView: WKWebView, callback: [String] -> Void) {
        didAttemptToFindFeed = true
        findFeedCallback = callback
    }

    init() {}
}
