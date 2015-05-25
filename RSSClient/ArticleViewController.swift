import UIKit
import WebKit
import TOBrowserActivityKit

class ArticleViewController: UIViewController, WKNavigationDelegate {
    var article: Article? = nil {
        didSet {
            self.navigationController?.setToolbarHidden(false, animated: false)
            if let a = article {
//                self.dataManager?.readArticle(a, read: true)
//                NSNotificationCenter.defaultCenter().postNotificationName("ArticleWasRead", object: a)
//                a.managedObjectContext?.save(nil)
                let url = a.link
                showArticle(a, onWebView: content)

                self.navigationItem.title = a.title ?? ""

                if userActivity == nil {
                    let activityType = "com.rachelbrindle.rssclient.article"
                    userActivity = NSUserActivity(activityType: activityType)
                    userActivity?.title = NSLocalizedString("Reading Article", comment: "")
                    userActivity?.becomeCurrent()
                }
                /*
                userActivity?.userInfo = ["feed": a.feed?.title ?? "",
                                          "article": a.objectID.URIRepresentation(),
                                          "showingContent": true,
                                          "url": a.link!]
                */
                userActivity?.webpageURL = a.link
                self.userActivity?.needsSave = true

                let localNotes = UIApplication.sharedApplication().scheduledLocalNotifications
                if let scheduledNotes = localNotes as? [UILocalNotification] {
                    let notes = scheduledNotes.filter {note in
                        if let ui = note.userInfo,
                            let feed: String = ui["feed"] as? String,
                            let title: String = ui["article"] as? String {
                                return feed == a.feed?.title && title == a.title
                        }
                        return false
                    }
                    for note in notes {
                        UIApplication.sharedApplication().cancelLocalNotification(note)
                    }
                }
            }
        }
    }

    enum ArticleContentType {
        case Content;
        case Link;
    }

    var content = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)

    var shareButton: UIBarButtonItem? = nil
    var toggleContentButton: UIBarButtonItem? = nil
    var showEnclosuresButton: UIBarButtonItem? = nil
    let contentString = NSLocalizedString("Content", comment: "")
    let linkString = NSLocalizedString("Link", comment: "")

    var articles: [Article] = []
    var lastArticleIndex = 0

    var dataManager: DataManager? = nil

    var articleCSS: String {
        if let loc = NSBundle.mainBundle().URLForResource("article", withExtension: "css") {
            if let str = NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding, error: nil) {
                return "<html><head><style type=\"text/css\">\(str)</style></head><body>"
            }
        }
        return "<html><body>"
    }

    var contentType: ArticleContentType = .Content {
        didSet {
            if let a = article {
                switch (contentType) {
                case .Content:
                    toggleContentButton?.title = linkString
                    let content = a.content ?? a.summary ?? ""
                    self.content.loadHTMLString(articleCSS + content + "</body></html>", baseURL: a.feed?.url)
                case .Link:
                    toggleContentButton?.title = contentString
                    self.content.loadRequest(NSURLRequest(URL: a.link!))
                }
                if (shareButton != nil && toggleContentButton != nil) {
                    if (a.content ?? a.summary) != nil {
                        self.toolbarItems = [spacer(), shareButton!, spacer(), toggleContentButton!, spacer()]
                    } else {
                        self.toolbarItems = [spacer(), shareButton!, spacer()]
                    }
                    if let ec = showEnclosuresButton {
                        if a.enclosures.count > 0 {
                            self.toolbarItems! += [ec, spacer()]
                        }
                    }
                }
            } else {
                self.toolbarItems = []
                self.content.loadHTMLString("", baseURL: nil)
            }
        }
    }

    func showArticle(article: Article, onWebView webView: WKWebView) {
        let content = article.content.isEmpty ? article.summary : article.content
        if !content.isEmpty {
            let title = "<h2>\(article.title)</h2>"
            webView.loadHTMLString(articleCSS + title + content + "</body></html>", baseURL: article.feed?.url!)
            if let sb = shareButton {
                self.toolbarItems = [spacer(), sb, spacer(), toggleContentButton!, spacer()]
                if let ec = showEnclosuresButton where article.enclosures.count > 0 {
                    self.toolbarItems! += [ec, spacer()]
                }
            }
        } else {
            webView.loadRequest(NSURLRequest(URL: article.link!))
            if let sb = shareButton {
                self.toolbarItems = [spacer(), sb, spacer()]
                if let ec = showEnclosuresButton where article.enclosures.count > 0 {
                    self.toolbarItems! += [ec, spacer()]
                }
            }
        }
    }

    func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None
        self.navigationController?.setToolbarHidden(false, animated: true)

        self.view.backgroundColor = UIColor.whiteColor()

        if userActivity == nil {
            userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
            userActivity?.title = NSLocalizedString("Reading Article", comment: "")
        }

        self.view.addSubview(loadingBar)
        loadingBar.setTranslatesAutoresizingMaskIntoConstraints(false)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 1)
        loadingBar.progressTintColor = UIColor.darkGreenColor()

        self.view.addSubview(content)
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        configureContent()

        let is6Plus = UIScreen.mainScreen().scale == UIScreen.mainScreen().nativeScale &&
                      UIScreen.mainScreen().scale > 2
        let isiPad = UIDevice.currentDevice().userInterfaceIdiom == .Pad
        if let splitView = self.splitViewController where isiPad || is6Plus {
            self.navigationItem.leftBarButtonItem = splitView.displayModeButtonItem()
        }

        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false

        self.navigationItem.rightBarButtonItems = [forward, back]
        // share, show (content|link)
        shareButton = UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: "share")
        toggleContentButton = UIBarButtonItem(title: linkString, style: .Plain,
            target: self, action: "toggleContentLink")
        if let a = article {
            if (a.content ?? a.summary) != nil {
                self.toolbarItems = [spacer(), shareButton!, spacer(), toggleContentButton!, spacer()]
            } else {
                self.toolbarItems = [spacer(), shareButton!, spacer()]
            }
            if a.enclosures.count > 0 && showEnclosuresButton != nil {
                self.toolbarItems! += [showEnclosuresButton!, spacer()]
            }
        }

        let swipeRight = UIScreenEdgePanGestureRecognizer(target: self, action: "next:")
        swipeRight.edges = .Right
        self.view.addGestureRecognizer(swipeRight)
        let swipeLeft = UIScreenEdgePanGestureRecognizer(target: self, action: "back:")
        swipeLeft.edges = .Left
        self.view.addGestureRecognizer(swipeLeft)
    }

    override func restoreUserActivityState(activity: NSUserActivity) {
        super.restoreUserActivityState(activity)

        if let ui = activity.userInfo, let showingContent = ui["showingContent"] as? Bool {
            if showingContent {
                self.contentType = .Content
            } else {
                self.contentType = .Link
            }
            if let url = ui["url"] as? NSURL {
                self.content.loadRequest(NSURLRequest(URL: url))
            }
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    var objectsBeingObserved: [WKWebView] = []

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        userActivity?.invalidate()
        userActivity = nil
        for obj in objectsBeingObserved {
            obj.removeObserver(self, forKeyPath: "estimatedProgress")
        }
        objectsBeingObserved = []
    }

    func removeObserverFromContent(obj: WKWebView) {
        var idx: Int? = nil
        do {
            idx = nil
            for (i, x) in enumerate(objectsBeingObserved) {
                if x == obj {
                    idx = i
                    x.removeObserver(self, forKeyPath: "estimatedProgress")
                    break
                }
            }
            if let i = idx {
                objectsBeingObserved.removeAtIndex(i)
            }
        } while idx != nil
    }

    deinit {
        userActivity?.invalidate()
    }

    func configureContent() {
        content.navigationDelegate = self
        self.view.bringSubviewToFront(self.loadingBar)
        if let items = self.navigationItem.rightBarButtonItems as? [UIBarButtonItem] {
            let forward = items[0]
            let back = items[1]
            forward.enabled = content.canGoForward
            back.enabled = content.canGoBack
        }
    }

    var nextContent: WKWebView = WKWebView(forAutoLayout: ())
    var nextContentRight: NSLayoutConstraint! = nil

    func showPopTip(text: String, fromPoint point: CGPoint, fromDirection direction: AMPopTipDirection) {
        let poptip = AMPopTip()
        poptip.popoverColor = UIColor.lightGrayColor()
        let rect = CGRectMake(point.x, point.y, 0, 0)
        let font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        let attributedText = NSAttributedString(string: text, attributes: [NSFontAttributeName: font])

        poptip.showAttributedText(attributedText, direction: direction, maxWidth: 120, inView: self.view,
            fromFrame: rect, duration: 2)
    }

    func back(gesture: UIScreenEdgePanGestureRecognizer) {
        if lastArticleIndex == 0 {
            showPopTip(NSLocalizedString("No previous article", comment: ""),
                fromPoint: gesture.locationInView(self.view), fromDirection: .Right)
            return
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width - gesture.translationInView(self.view).x
        if gesture.state == .Began {
            let a = articles[lastArticleIndex-1]
            nextContent = WKWebView(forAutoLayout: ())
            self.view.addSubview(nextContent)
            self.showArticle(a, onWebView: nextContent)
            nextContent.autoPinEdgeToSuperviewEdge(.Top)
            nextContent.autoPinEdgeToSuperviewEdge(.Bottom)
            nextContent.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            nextContentRight = nextContent.autoPinEdgeToSuperviewEdge(.Right, withInset: translation)
        } else if gesture.state == .Changed {
            nextContentRight.constant = translation
        } else if gesture.state == .Cancelled {
            nextContent.removeFromSuperview()
            self.removeObserverFromContent(nextContent)
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x
            if speed >= 0 {
                lastArticleIndex--
                article = articles[lastArticleIndex]
                nextContentRight.constant = 0
                let oldContent = content
                content = nextContent
                configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(completed) in
                    self.view.bringSubviewToFront(self.loadingBar)
                    oldContent.removeFromSuperview()
                    self.removeObserverFromContent(oldContent)
                })
            } else {
                nextContent.removeFromSuperview()
                self.removeObserverFromContent(nextContent)
            }
        }
    }

    func next(gesture: UIScreenEdgePanGestureRecognizer) {
        if lastArticleIndex + 1 >= articles.count {
            if gesture.state == .Began {
                let point = CGPointMake(self.view.bounds.width, gesture.locationInView(self.view).y)
                showPopTip(NSLocalizedString("End of article list", comment: ""),
                    fromPoint: point, fromDirection: .Left)
            }
            return;
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width + gesture.translationInView(self.view).x
        if gesture.state == .Began {
            let a = articles[lastArticleIndex+1]
            nextContent = WKWebView(forAutoLayout: ())
            self.view.addSubview(nextContent)
            self.showArticle(a, onWebView: nextContent)
            nextContent.autoPinEdgeToSuperviewEdge(.Top)
            nextContent.autoPinEdgeToSuperviewEdge(.Bottom)
            nextContent.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            nextContentRight = nextContent.autoPinEdgeToSuperviewEdge(.Right, withInset: translation)
        } else if gesture.state == .Changed {
            nextContentRight.constant = translation
        } else if gesture.state == .Cancelled {
            nextContent.removeFromSuperview()
            self.removeObserverFromContent(nextContent)
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x * -1
            if speed >= 0 {
                lastArticleIndex++
                article = articles[lastArticleIndex]
                nextContentRight.constant = 0
                let oldContent = content
                content = nextContent
                configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(completed) in
                    self.view.bringSubviewToFront(self.loadingBar)
                    oldContent.removeFromSuperview()
                    self.removeObserverFromContent(oldContent)
                })
            } else {
                nextContent.removeFromSuperview()
                self.removeObserverFromContent(nextContent)
            }
        }
    }

    func share() {
        if let a = article {
            let safari = TOActivitySafari()
            let chrome = TOActivityChrome()

            let activity = UIActivityViewController(activityItems: [a.link!],
                applicationActivities: [safari, chrome])
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: activity)
                popover.presentPopoverFromBarButtonItem(shareButton!, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(activity, animated: true, completion: nil)
            }
        }
    }

    func toggleContentLink() {
        switch (self.contentType) {
        case .Link:
            self.contentType = .Content
            self.userActivity?.userInfo?["showingContent"] = true
            self.userActivity?.userInfo?["url"] = NSNull()
        case .Content:
            self.contentType = .Link
            self.userActivity?.userInfo?["showingContent"] = false
//            self.userActivity?.userInfo?["url"] = NSURL(string: self.article?.link ?? "")!
        }
        self.userActivity?.needsSave = true
    }

    func showEnclosures() {
        if let enclosures = article?.enclosures {
            let activity = EnclosuresViewController()
            activity.dataManager = dataManager

            let navController = UINavigationController(rootViewController: activity)

            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: navController)
                popover.presentPopoverFromBarButtonItem(showEnclosuresButton!, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(navController, animated: true, completion: nil)
            }
        }
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && (object as? NSObject) == content) {
            loadingBar.progress = Float(content.estimatedProgress)
        }
    }

    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        loadingBar.hidden = true
        self.removeObserverFromContent(webView)
    }

    func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError _: NSError) {
        loadingBar.hidden = true
        self.removeObserverFromContent(webView)
    }

    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingBar.progress = 0
        loadingBar.hidden = false
        if !contains(objectsBeingObserved, webView) {
            webView.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
            objectsBeingObserved.append(webView)
        }
        if let wvu = webView.URL {
//            if wvu != NSURL(string: self.article?.feed?.url ?? "") {
//                self.userActivity?.userInfo?["url"] = wvu
//                self.userActivity?.needsSave = true
//                self.userActivity?.webpageURL = wvu
//            }
        }
        if let items = self.navigationItem.rightBarButtonItems as? [UIBarButtonItem] {
            let forward = items[0]
            let back = items[1]
            forward.enabled = content.canGoForward
            back.enabled = content.canGoBack
        }
    }
}
