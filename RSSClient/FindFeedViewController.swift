import UIKit
import WebKit
import Muon
import rNewsKit

public class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    public lazy var webContent = WKWebView(forAutoLayout: ())

    public let loadingBar = UIProgressView(progressViewStyle: .Bar)
    public let navField = UITextField(frame: CGRectMake(0, 0, 200, 30))
    private var rssLink: String? = nil

    public var addFeedButton: UIBarButtonItem! = nil
    var back: UIBarButtonItem! = nil
    var forward: UIBarButtonItem! = nil
    public var reload: UIBarButtonItem! = nil
    var cancelTextEntry: UIBarButtonItem! = nil

    var lookForFeeds: Bool = true

    private lazy var feedFinder: FeedFinder? = {
        self.injector?.create(FeedFinder.self) as? FeedFinder
    }()

    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    private lazy var opmlManager: OPMLManager? = {
        return self.injector?.create(OPMLManager.self) as? OPMLManager
    }()

    private lazy var mainQueue: NSOperationQueue? = {
        return self.injector?.create(kMainQueue) as? NSOperationQueue
    }()

    private lazy var backgroundQueue: NSOperationQueue? = {
        return self.injector?.create(kBackgroundQueue) as? NSOperationQueue
    }()

    private lazy var urlSession: NSURLSession? = {
        return self.injector?.create(NSURLSession.self) as? NSURLSession
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None

        webContent.navigationDelegate = self
        self.view.addSubview(webContent)
        webContent.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)

        back = UIBarButtonItem(title: "<", style: .Plain, target: webContent, action: "goBack")
        forward = UIBarButtonItem(title: ">", style: .Plain, target: webContent, action: "goForward")

        let addFeedTitle = NSLocalizedString("Add Feed", comment: "")
        addFeedButton = UIBarButtonItem(title: addFeedTitle, style: .Plain, target: self, action: "save")
        back.enabled = false
        forward.enabled = false
        addFeedButton.enabled = false

        let dismissTitle = NSLocalizedString("Dismiss", comment: "")
        let dismiss = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        reload = UIBarButtonItem(barButtonSystemItem: .Refresh, target: webContent, action: "reload")

        let cancelTitle = NSLocalizedString("Cancel", comment: "")
        cancelTextEntry = UIBarButtonItem(title: cancelTitle, style: .Plain,
            target: navField, action: "resignFirstResponder")
        cancelTextEntry.tintColor = UIColor.darkTextColor()

        self.navigationController?.toolbarHidden = false
        func spacer() -> UIBarButtonItem {
            return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
        }
        if (lookForFeeds) {
            self.toolbarItems = [back, forward, spacer(), dismiss, spacer(), addFeedButton]
        } else {
            self.toolbarItems = [back, forward, spacer(), dismiss]
        }

        self.navigationItem.titleView = navField
        navField.delegate = self
        navField.placeholder = "Enter URL"
        navField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        navField.layer.cornerRadius = 5
        navField.autocorrectionType = .No
        navField.autocapitalizationType = .None
        navField.keyboardType = .URL
        navField.clearsOnBeginEditing = true

        loadingBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(loadingBar)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 1)
        loadingBar.progress = 0
        loadingBar.hidden = true
        loadingBar.progressTintColor = UIColor.darkGreenColor()
    }
    deinit {
        webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func save() {
        if let rl = rssLink {
            save(rl)
        } else {
            dismiss()
        }
    }

    private func save(link: String, opml: Bool = false) {
        // show something to indicate we're doing work...
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.navigationController?.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        let feedMessageTemplate = NSLocalizedString("Loading feed at %@", comment: "")
        let opmlMessageTemplate = NSLocalizedString("Loading feed list at %@", comment: "")

        let messageTemplate = opml ? opmlMessageTemplate : feedMessageTemplate
        let message = NSString.localizedStringWithFormat(messageTemplate, link) as String
        indicator.configureWithMessage(message)
        if opml {
            opmlManager?.importOPML(NSURL(string: link)!) {(_) in
                indicator.removeFromSuperview()
                self.dismiss()
            }
        } else {
            dataWriter?.newFeed {newFeed in
                newFeed.url = NSURL(string: link)
                self.dataWriter?.saveFeed(newFeed)
                self.dataWriter?.updateFeeds {_, _ in
                    indicator.removeFromSuperview()
                    self.dismiss()
                }
            }
        }
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?,
        change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as? NSObject == webContent) {
            loadingBar.progress = Float(webContent.estimatedProgress)
        }
    }

    // MARK: - UITextFieldDelegate

    public func textFieldDidBeginEditing(textField: UITextField) {
        self.navigationItem.setRightBarButtonItem(cancelTextEntry, animated: true)
    }

    public func textFieldDidEndEditing(textField: UITextField) {
        var button: UIBarButtonItem? = nil
        if (webContent.estimatedProgress >= 1.0) {
            button = reload
        }
        self.navigationItem.setRightBarButtonItem(button, animated: true)
    }

    public func textFieldShouldReturn(textField: UITextField) -> Bool {
        let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        textField.text = textField.text?.stringByTrimmingCharactersInSet(whitespace)
        if let text = textField.text where text.lowercaseString.hasPrefix("http") == false {
            textField.text = "http://\(text)"
        }
        if let text = textField.text, let url = NSURL(string: text) {
            self.webContent.loadRequest(NSURLRequest(URL: url))
        }
        textField.placeholder = NSLocalizedString("Loading", comment: "")
        textField.resignFirstResponder()

        return true
    }

    // MARK: - WKNavigationDelegate

    public func webView(webView: WKWebView, didFinishNavigation _: WKNavigation!) {
//        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
        navField.placeholder = webView.title
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
        self.navigationItem.rightBarButtonItem = reload

        guard self.lookForFeeds else {
            return
        }

        self.feedFinder?.findUnknownFeedInCurrentWebView(webView) {feedUrl in
            self.rssLink = feedUrl
            self.addFeedButton.enabled = feedUrl != nil
        }
    }

    public func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError error: NSError) {
//        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
    }

    public func webView(webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: NSError) {
//        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
    }

    public func webView(webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        loadingBar.progress = 0
        loadingBar.hidden = false
        navField.text = ""
        navField.placeholder = NSLocalizedString("Loading", comment: "")
        addFeedButton.enabled = false
        if let url = webView.URL where lookForFeeds {
            self.urlSession?.dataTaskWithURL(url) {data, response, error in
                guard let data = data, let text = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
                    return
                }

                let doNotSave = NSLocalizedString("Don't Import", comment: "")
                let save = NSLocalizedString("Import", comment: "")

                let feedParser = FeedParser(string: text)
                let opmlParser = OPMLParser(text: text).success {_ in
                    feedParser.cancel()

                    let detected = NSLocalizedString("Feed list Detected", comment: "")
                    let shouldImport = NSLocalizedString("Import?", comment: "")

                    let alert = UIAlertController(title: detected, message: shouldImport, preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: doNotSave, style: .Cancel,
                        handler: {_ in
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                    }))
                    alert.addAction(UIAlertAction(title: save, style: .Default, handler: {_ in
                        alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        self.save(url.absoluteString, opml: true)
                    }))
                    self.mainQueue?.addOperationWithBlock {
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                }
                feedParser.success {feed in
                    opmlParser.cancel()

                    let detected = NSLocalizedString("Feed Detected", comment: "")
                    let saveFormatString = NSLocalizedString("Import %@?", comment: "")
                    let saveFeed = String.localizedStringWithFormat(saveFormatString, feed.title)
                    let alert = UIAlertController(title: detected, message: saveFeed, preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: doNotSave, style: .Cancel,
                        handler: {(alertAction: UIAlertAction!) in
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                    }))
                    alert.addAction(UIAlertAction(title: save, style: .Default, handler: {(_) in
                        alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        self.save(url.absoluteString, opml: false)
                    }))
                    self.mainQueue?.addOperationWithBlock {
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                }

                self.backgroundQueue?.addOperation(opmlParser)
                self.backgroundQueue?.addOperation(feedParser)
            }?.resume()
        }
    }
}
