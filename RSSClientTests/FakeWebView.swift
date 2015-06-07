import UIKit
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

    var lastRequestLoaded: NSURLRequest? = nil
    override func loadRequest(request: NSURLRequest) -> WKNavigation? {
        lastRequestLoaded = request
        return nil
    }

    var lastJavascriptEvaluated: String? = nil
    var lastJavascriptHandler: (AnyObject!, NSError!) -> Void = {_ in }
    override func evaluateJavaScript(javaScriptString: String, completionHandler: ((AnyObject!, NSError!) -> Void)?) {
        lastJavascriptEvaluated = javaScriptString
        if let handler = completionHandler {
            lastJavascriptHandler = handler
        }
    }
}
