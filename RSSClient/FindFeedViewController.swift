import UIKit
import WebKit
import Alamofire
import Muon

public class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    public let webContent = WKWebView(forAutoLayout: ())
    public let loadingBar = UIProgressView(progressViewStyle: .Bar)
    public let navField = UITextField(frame: CGRectMake(0, 0, 200, 30))
    private var rssLink: String? = nil

    public var addFeedButton: UIBarButtonItem! = nil
    var back: UIBarButtonItem! = nil
    var forward: UIBarButtonItem! = nil
    public var reload: UIBarButtonItem! = nil
    var cancelTextEntry: UIBarButtonItem! = nil

    var lookForFeeds: Bool = true

    var feeds: [String] = []

    lazy var dataManager: DataManager = {
        return self.injector!.create(DataManager.self) as! DataManager
    }()

    lazy var mainQueue: NSOperationQueue = {
        return self.injector!.create(kMainQueue) as! NSOperationQueue
    }()

    lazy var backgroundQueue: NSOperationQueue = {
        return self.injector!.create(kBackgroundQueue) as! NSOperationQueue
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

        loadingBar.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(loadingBar)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 1)
        loadingBar.progress = 0
        loadingBar.hidden = true
        loadingBar.progressTintColor = UIColor.darkGreenColor()
    }

    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if (lookForFeeds) {
//            feeds = dataManager.feeds().reduce([], combine: {
//                if let url = $1.url?.absoluteString {
//                    return $0 + [url]
//                }
//                return $0
//            })
        }
    }

    deinit {
        webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func save() {
        if let rl = rssLink {
            save(rl)
        } else {
            dismiss()
        }
    }

    func save(link: String, opml: Bool = false) {
        // show something to indicate we're doing work...
        let loading = LoadingView(frame: self.view.bounds)
        self.view.addSubview(loading)
        let loadingMessage = NSLocalizedString("Loading feed at %@", comment: "")
        loading.msg = NSString.localizedStringWithFormat(loadingMessage, link) as String
        if opml {
            dataManager.importOPML(NSURL(string: link)!, progress: {(_) in }) {(_) in
                loading.removeFromSuperview()
                self.navigationController?.toolbarHidden = false
                self.navigationController?.navigationBarHidden = false
                self.dismiss()
            }
        } else {
            dataManager.newFeed(link) {(error) in
                if let err = error {
                    println("\(err)")
                }
                loading.removeFromSuperview()
                self.navigationController?.toolbarHidden = false
                self.navigationController?.navigationBarHidden = false
                self.dismiss()
            }
        }
    }

    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject,
        change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
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
        textField.text = textField.text.stringByTrimmingCharactersInSet(whitespace)
        if !textField.text.lowercaseString.hasPrefix("http") {
            textField.text = "http://\(textField.text)"
        }
        if let url = NSURL(string: textField.text) {
            self.webContent.loadRequest(NSURLRequest(URL: NSURL(string: textField.text)!))
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

        if let findFeedsJS = NSBundle.mainBundle().pathForResource("findFeeds", ofType: "js"),
           let discover = String(contentsOfFile: findFeedsJS,
            encoding: NSUTF8StringEncoding, error: nil) where lookForFeeds {
                webView.evaluateJavaScript(discover, completionHandler: {(res: AnyObject!, error: NSError?) in
                    if let str = res as? String {
                        if (!contains(self.feeds, str)) {
                            self.rssLink = str
                            self.addFeedButton.enabled = true
                        }
                    } else {
                        self.rssLink = nil
                    }
                    if (error != nil) {
                        println("Error executing javascript: \(error)")
                    }
                })
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
        if let text = webView.URL?.absoluteString where lookForFeeds {
            Alamofire.request(.GET, text).responseString {(_, _, response, error) in
                if let txt = response {
                    let doNotSave = NSLocalizedString("Don't Save", comment: "")
                    let save = NSLocalizedString("Save", comment: "")

                    let feedParser = Muon.FeedParser(string: txt)
                    let opmlParser = OPMLParser(text: txt).success{(_) in
                        feedParser.cancel()

                        let detected = NSLocalizedString("Feed list Detected", comment: "")
                        let shouldImport = NSLocalizedString("Import?", comment: "")

                        let alert = UIAlertController(title: detected, message: shouldImport, preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: doNotSave, style: .Cancel,
                            handler: {(alertAction: UIAlertAction!) in
                                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        }))
                        alert.addAction(UIAlertAction(title: save, style: .Default, handler: {(_) in
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                            self.save(text, opml: true)
                        }))
                        self.mainQueue.addOperationWithBlock {
                            self.presentViewController(alert, animated: true, completion: nil)
                        }
                    }
                    feedParser.success {info in
                        let string = info.link.absoluteString ?? text
                        opmlParser.cancel()
                        if (!contains(self.feeds, text)) {
                            let detected = NSLocalizedString("Feed Detected", comment: "")
                            let saveFormatString = NSLocalizedString("Save %@?", comment: "")
                            let saveFeed = String.localizedStringWithFormat(saveFormatString, text)
                            let alert = UIAlertController(title: detected, message: saveFeed, preferredStyle: .Alert)
                            alert.addAction(UIAlertAction(title: doNotSave, style: .Cancel,
                                handler: {(alertAction: UIAlertAction!) in
                                    alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                            }))
                            alert.addAction(UIAlertAction(title: save, style: .Default, handler: {(_) in
                                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                                self.save(string, opml: false)
                            }))
                            self.mainQueue.addOperationWithBlock {
                                self.presentViewController(alert, animated: true, completion: nil)
                            }
                        }
                    }
                    self.backgroundQueue.addOperations([opmlParser, feedParser], waitUntilFinished: false)
                }
            }
        }
    }
}
