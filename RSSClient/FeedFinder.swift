import Foundation
import WebKit

public protocol FeedFinder {
    func findUnknownFeedInCurrentWebView(webView: WKWebView, callback: [String] -> Void)
}

public class WebFeedFinder: FeedFinder {
    private lazy var discoverScript: String = {
        let findFeedsJsPath = NSBundle.mainBundle().pathForResource("findFeeds", ofType: "js")
        return (try? String(contentsOfFile: findFeedsJsPath!, encoding: NSUTF8StringEncoding)) ?? ""
    }()

    lazy var feeds: [String] = []

    public func findUnknownFeedInCurrentWebView(webView: WKWebView, callback: [String] -> Void) {
        webView.evaluateJavaScript(discoverScript) {res, error in
            if let potentialFeeds = res as? [String] {
                let unimportedFeeds = potentialFeeds.filter { !self.feeds.contains($0) }
                callback(unimportedFeeds)
                return
            }
            callback([])
        }
    }

    init() {}
}
