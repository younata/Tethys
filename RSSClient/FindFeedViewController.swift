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

    private lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    private lazy var placeholderAttributes: [String: AnyObject] = [NSForegroundColorAttributeName: UIColor.blackColor()]

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None

        self.webContent.navigationDelegate = self
        self.view.addSubview(self.webContent)
        self.webContent.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)

        self.back = UIBarButtonItem(title: "<", style: .Plain, target: self.webContent, action: "goBack")
        self.forward = UIBarButtonItem(title: ">", style: .Plain, target: self.webContent, action: "goForward")

        let addFeedTitle = NSLocalizedString("FindFeedViewController_AddFeed", comment: "")
        self.addFeedButton = UIBarButtonItem(title: addFeedTitle, style: .Plain, target: self, action: "save")
        self.back.enabled = false
        self.forward.enabled = false
        self.addFeedButton.enabled = false

        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismiss = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.reload = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self.webContent, action: "reload")

        let cancelTitle = NSLocalizedString("FindFeedViewController_Cancel", comment: "")
        self.cancelTextEntry = UIBarButtonItem(title: cancelTitle, style: .Plain,
            target: self.navField, action: "resignFirstResponder")

        self.navigationController?.toolbarHidden = false
        func spacer() -> UIBarButtonItem {
            return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
        }
        if (self.lookForFeeds) {
            self.toolbarItems = [self.back, self.forward, spacer(), dismiss, spacer(), self.addFeedButton]
        } else {
            self.toolbarItems = [self.back, self.forward, spacer(), dismiss]
        }

        self.navigationItem.titleView = self.navField
        self.navField.frame = CGRectMake(0, 0, self.view.bounds.size.width * 0.8, 32)
        self.navField.delegate = self
        self.navField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("FindFeedViewController_URLBar_Placeholder", comment: ""), attributes: self.placeholderAttributes)
        self.navField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        self.navField.layer.cornerRadius = 5
        self.navField.autocorrectionType = .No
        self.navField.autocapitalizationType = .None
        self.navField.keyboardType = .URL
        self.navField.clearsOnBeginEditing = true

        self.loadingBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.loadingBar)
        self.loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        self.loadingBar.autoSetDimension(.Height, toSize: 1)
        self.loadingBar.progress = 0
        self.loadingBar.hidden = true
        self.loadingBar.progressTintColor = UIColor.darkGreenColor()

        self.themeRepository?.addSubscriber(self)
    }
    deinit {
        self.webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    public override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)

        self.navField.frame = CGRectMake(0, 0, size.width * 0.8, 32)
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func save() {
        if let rl = self.rssLink {
            self.save(rl)
        } else {
            self.dismiss()
        }
    }

    private func save(link: String, opml: Bool = false) {
        // show something to indicate we're doing work...
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.navigationController?.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        let feedMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed", comment: "")
        let opmlMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed_List", comment: "")

        let messageTemplate = opml ? opmlMessageTemplate : feedMessageTemplate
        let message = NSString.localizedStringWithFormat(messageTemplate, link) as String
        indicator.configureWithMessage(message)
        if opml {
            self.opmlManager?.importOPML(NSURL(string: link)!) {(_) in
                indicator.removeFromSuperview()
                self.dismiss()
            }
        } else {
            self.dataWriter?.newFeed {newFeed in
                newFeed.url = NSURL(string: link)
                self.dataWriter?.saveFeed(newFeed)
                self.dataWriter?.updateFeed(newFeed) {_, _ in
                    indicator.removeFromSuperview()
                    self.dismiss()
                }
            }
        }
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?,
        change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as? NSObject == self.webContent) {
            self.loadingBar.progress = Float(self.webContent.estimatedProgress)
        }
    }

    // MARK: - UITextFieldDelegate

    public func textFieldDidBeginEditing(textField: UITextField) {
        self.navigationItem.setRightBarButtonItem(self.cancelTextEntry, animated: true)
    }

    public func textFieldDidEndEditing(textField: UITextField) {
        var button: UIBarButtonItem? = nil
        if (self.webContent.estimatedProgress >= 1.0) {
            button = self.reload
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
            self.self.webContent.loadRequest(NSURLRequest(URL: url))
        }
        textField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: ""), attributes: self.placeholderAttributes)
        textField.resignFirstResponder()

        return true
    }

    // MARK: - WKNavigationDelegate

    public func webView(webView: WKWebView, didFinishNavigation _: WKNavigation!) {
        self.loadingBar.hidden = true
        self.navField.attributedPlaceholder = NSAttributedString(string: webView.title ?? "", attributes: self.placeholderAttributes)
        self.forward.enabled = webView.canGoForward
        self.back.enabled = webView.canGoBack
        self.navigationItem.rightBarButtonItem = self.reload

        guard self.lookForFeeds else {
            return
        }

        self.feedFinder?.findUnknownFeedInCurrentWebView(webView) {feedUrl in
            self.rssLink = feedUrl
            self.self.addFeedButton.enabled = feedUrl != nil
        }
    }

    public func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError error: NSError) {
        self.loadingBar.hidden = true
    }

    public func webView(webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: NSError) {
        self.loadingBar.hidden = true
    }

    public func webView(webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        self.loadingBar.progress = 0
        self.loadingBar.hidden = false
        self.navField.text = ""
        self.navField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: ""), attributes: self.placeholderAttributes)
        self.addFeedButton.enabled = false
        if let url = webView.URL where lookForFeeds {
            self.urlSession?.dataTaskWithURL(url) {data, response, error in
                guard let data = data, let text = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
                    return
                }

                let doNotSave = NSLocalizedString("FindFeedViewController_FoundFeed_Decline", comment: "")
                let save = NSLocalizedString("FindFeedViewController_FoundFeed_Accept", comment: "")

                let feedParser = FeedParser(string: text)
                let opmlParser = OPMLParser(text: text).success {_ in
                    feedParser.cancel()

                    let detected = NSLocalizedString("FindFeedViewController_FoundFeed_List_Title", comment: "")
                    let shouldImport = NSLocalizedString("FindFeedViewController_FoundFeed_List_Subtitle", comment: "")

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

                    let detected = NSLocalizedString("FindFeedViewController_FoundFeed_Title", comment: "")
                    let saveFormatString = NSLocalizedString("FindFeedViewController_FoundFeed_Subtitle", comment: "")
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
            }.resume()
        }
    }
}

extension FindFeedViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        if let themeRepository = self.themeRepository {
            self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
            self.navigationController?.toolbar.barStyle = themeRepository.barStyle
        }

        self.webContent.backgroundColor = self.themeRepository?.backgroundColor
    }
}
