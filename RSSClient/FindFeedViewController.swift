import UIKit
import WebKit
import Alamofire
import Muon

class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    let webContent = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)
    let navField = UITextField(frame: CGRectMake(0, 0, 200, 30))
    private var rssLink: String? = nil
    
    var addFeedButton: UIBarButtonItem! = nil
    var back: UIBarButtonItem! = nil
    var forward: UIBarButtonItem! = nil
    var reload: UIBarButtonItem! = nil
    var cancelTextEntry : UIBarButtonItem! = nil
    
    var lookForFeeds : Bool = true
    
    var feeds: [String] = []

    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as! DataManager }()
    lazy var mainQueue : NSOperationQueue = { self.injector!.create(kMainQueue) as! NSOperationQueue }()
    lazy var backgroundQueue : NSOperationQueue = { self.injector!.create(kBackgroundQueue) as! NSOperationQueue }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None
        
        webContent.navigationDelegate = self
        self.view.addSubview(webContent)
        webContent.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
                
        back = UIBarButtonItem(title: "<", style: .Plain, target: webContent, action: "goBack")
        forward = UIBarButtonItem(title: ">", style: .Plain, target: webContent, action: "goForward")
        addFeedButton = UIBarButtonItem(title: NSLocalizedString("Add Feed", comment: ""), style: .Plain, target: self, action: "save")
        back.enabled = false
        forward.enabled = false
        addFeedButton.enabled = false
        
        let dismiss = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        reload = UIBarButtonItem(barButtonSystemItem: .Refresh, target: webContent, action: "reload")
        cancelTextEntry = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .Plain, target: navField, action: "resignFirstResponder")
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
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if (lookForFeeds) {
            let dataManager = self.injector!.create(DataManager.self) as! DataManager
            feeds = dataManager.feeds().reduce([], combine: {
                if let url = $1.url?.absoluteString {
                    return $0 + [url]
                }
                return $0
            })
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
        loading.msg = NSString.localizedStringWithFormat(NSLocalizedString("Loading feed at %@", comment: ""), link) as String
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
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as? NSObject == webContent) {
            loadingBar.progress = Float(webContent.estimatedProgress)
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidBeginEditing(textField: UITextField) {
        self.navigationItem.setRightBarButtonItem(cancelTextEntry, animated: true)
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        var button : UIBarButtonItem? = nil
        if (webContent.estimatedProgress >= 1.0) {
            button = reload
        }
        self.navigationItem.setRightBarButtonItem(button, animated: true)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.text = textField.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
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
    
    func webView(webView: WKWebView, didFinishNavigation _: WKNavigation!) {
//        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
        navField.placeholder = webView.title
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
        self.navigationItem.rightBarButtonItem = reload

        if (lookForFeeds) {
            let discover = NSString(contentsOfFile: NSBundle.mainBundle().pathForResource("findFeeds", ofType: "js")!, encoding: NSUTF8StringEncoding, error: nil)!
            webView.evaluateJavaScript(discover as String, completionHandler: {(res: AnyObject!, error: NSError?) in
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
    
    func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError error: NSError) {
//        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
    }

    func webView(webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: NSError) {
//        self.navigationItem.titleView = self.navField
        loadingBar.hidden = true
    }
    
    func webView(webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        loadingBar.progress = 0
        loadingBar.hidden = false
        navField.text = ""
        navField.placeholder = NSLocalizedString("Loading", comment: "")
        addFeedButton.enabled = false
        if let text = webView.URL?.absoluteString where lookForFeeds {
            Alamofire.request(.GET, text).responseString {(_, _, response, error) in
                if let txt = response {
                    let feedParser = Muon.FeedParser(string: txt)
                    let opmlParser = OPMLParser(text: txt).success{(_) in
                        feedParser.cancel()
                        let alert = UIAlertController(title: NSLocalizedString("Feed list Detected", comment: ""), message: NSLocalizedString("Import?", comment: ""), preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Don't Save", comment: ""), style: .Cancel, handler: {(alertAction: UIAlertAction!) in
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .Default, handler: {(_) in
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
                            let alert = UIAlertController(title: NSLocalizedString("Feed Detected", comment: ""), message: NSString.localizedStringWithFormat(NSLocalizedString("Save %@?", comment: ""), text) as String, preferredStyle: .Alert)
                            alert.addAction(UIAlertAction(title: NSLocalizedString("Don't Save", comment: ""), style: .Cancel, handler: {(alertAction: UIAlertAction!) in
                                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                            }))
                            alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .Default, handler: {(_) in
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
