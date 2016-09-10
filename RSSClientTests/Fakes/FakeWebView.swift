import Foundation
import WebKit

class FakeWebView: WKWebView {

    var goBackCalled = false
    override func goBack() -> WKNavigation? {
        goBackCalled = true
        return nil
    }

    var goForwardCalled = false
    override func goForward() -> WKNavigation? {
        goForwardCalled = true
        return nil
    }

    var reloadCalled = false
    override func reload() -> WKNavigation? {
        reloadCalled = true
        return nil
    }

    var fakeUrl: Foundation.URL? = nil

    override var url: Foundation.URL {
        return fakeUrl ?? Foundation.URL(string: "http://example.com")!
    }

    var lastJavascriptEvaluated: String? = nil
    var lastJavascriptHandler: (AnyObject?, NSError?) -> Void = {_ in }
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((AnyObject?, NSError?) -> Void)?) {
        lastJavascriptEvaluated = javaScriptString
        if let handler = completionHandler {
            lastJavascriptHandler = handler
        }
    }
}
