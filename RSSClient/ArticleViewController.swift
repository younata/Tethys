import UIKit
import WebKit
import TOBrowserActivityKit
import Ra
import rNewsKit

public class ArticleViewController: UIViewController, WKNavigationDelegate {
    public var article: Article? = nil {
        didSet {
            self.navigationController?.setToolbarHidden(false, animated: false)
            if let a = article {
                self.dataWriter?.markArticle(a, asRead: true)
                self.showArticle(a, onWebView: self.content)

                self.navigationItem.title = a.title ?? ""

                if self.userActivity == nil {
                    let activityType = "com.rachelbrindle.rssclient.article"
                    self.userActivity = NSUserActivity(activityType: activityType)
                    self.userActivity?.title = NSLocalizedString("Reading Article", comment: "")
                    self.userActivity?.becomeCurrent()
                }

                self.userActivity?.userInfo = ["feed": a.feed?.title ?? "",
                                               "article": a.identifier,
                                               "showingContent": true]

                if #available(iOS 9.0, *) {
                    self.userActivity?.keywords = Set<String>([a.title, a.summary, a.author] + a.flags)
                }

                self.userActivity?.webpageURL = a.link
                self.userActivity?.needsSave = true
            }
        }
    }

    private enum ArticleContentType {
        case Content;
        case Link;
    }

    public var content = WKWebView(forAutoLayout: ())
    public let loadingBar = UIProgressView(progressViewStyle: .Bar)

    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: "share")
    }()
    public private(set) lazy var toggleContentButton: UIBarButtonItem = {
        return UIBarButtonItem(title: self.linkString, style: .Plain, target: self, action: "toggleContentLink")
    }()
    private let contentString = NSLocalizedString("Content", comment: "")
    private let linkString = NSLocalizedString("Link", comment: "")

    public var articles: [Article] = []
    public var lastArticleIndex = 0

    public lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    public lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    public lazy var swipeRight: UIScreenEdgePanGestureRecognizer = {
        return UIScreenEdgePanGestureRecognizer(target: self, action: "next:")
    }()

    private func loadArticleCSS() -> String {
        if let cssFileName = self.themeRepository?.articleCSSFileName, let loc = NSBundle.mainBundle().URLForResource(cssFileName, withExtension: "css") {
            do {
                let str = try NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding)
                return "<html><head><style type=\"text/css\">\(str)</style></head><body>"
            } catch _ {
            }
        }
        return "<html><body>"
    }

    private lazy var articleCSS: String = {
        return self.loadArticleCSS()
    }()

    private lazy var prismJS: String = {
        if let loc = NSBundle.mainBundle().URLForResource("prism.js", withExtension: "html") {
            do {
                return try NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding) as String
            } catch _ {
            }
        }
        return ""
    }()

    private var contentType: ArticleContentType = .Content {
        didSet {
            if let a = self.article {
                switch (self.contentType) {
                case .Content:
                    self.toggleContentButton.title = self.linkString
                    self.showArticle(a, onWebView: self.content)
                case .Link:
                    self.toggleContentButton.title = self.contentString
                    self.content.loadRequest(NSURLRequest(URL: a.link!))
                }
                if (a.content ?? a.summary) != nil {
                    self.toolbarItems = [self.spacer(), self.shareButton, self.spacer(), self.toggleContentButton, self.spacer()]
                } else {
                    self.toolbarItems = [self.spacer(), self.shareButton, self.spacer()]
                }
            } else {
                self.toolbarItems = []
                self.content.loadHTMLString("", baseURL: nil)
            }
        }
    }

    private func showArticle(article: Article, onWebView webView: WKWebView) {
        let content = article.content.isEmpty ? article.summary : article.content
        if !content.isEmpty {
            let title = "<h2>\(article.title)</h2>"
            webView.loadHTMLString(self.articleCSS + title + content + self.prismJS + "</body></html>", baseURL: article.feed?.url!)
            self.toolbarItems = [self.spacer(), self.shareButton, self.spacer(), self.toggleContentButton, self.spacer()]
        } else if let link = article.link {
            webView.loadRequest(NSURLRequest(URL: link))
            self.toolbarItems = [self.spacer(), self.shareButton, self.spacer()]
        }
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None
        self.navigationController?.setToolbarHidden(false, animated: true)

        self.view.backgroundColor = UIColor.whiteColor()

        if userActivity == nil {
            userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
            userActivity?.title = NSLocalizedString("Reading Article", comment: "")
            if #available(iOS 9.0, *) {
                userActivity?.eligibleForPublicIndexing = false
                userActivity?.eligibleForSearch = true
            }
            userActivity?.becomeCurrent()
        }

        self.view.addSubview(self.loadingBar)
        self.loadingBar.translatesAutoresizingMaskIntoConstraints = false
        self.loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        self.loadingBar.autoSetDimension(.Height, toSize: 1)
        self.loadingBar.progressTintColor = UIColor.darkGreenColor()

        self.view.addSubview(self.content)
        self.content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        self.configureContent()

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
        if let a = article {
            if (a.content ?? a.summary) != nil {
                self.toolbarItems = [self.spacer(), self.shareButton, self.spacer(), self.toggleContentButton, self.spacer()]
            } else {
                self.toolbarItems = [self.spacer(), self.shareButton, self.spacer()]
            }
        }

        self.swipeRight.edges = .Right
        self.view.addGestureRecognizer(self.swipeRight)

        self.themeRepository?.addSubscriber(self)
    }

    public override func restoreUserActivityState(activity: NSUserActivity) {
        super.restoreUserActivityState(activity)

        if let userInfo = activity.userInfo, let showingContent = userInfo["showingContent"] as? Bool {
            if showingContent {
                self.contentType = .Content
            } else {
                self.contentType = .Link
            }
            if let url = activity.webpageURL {
                self.content.loadRequest(NSURLRequest(URL: url))
            }
        }
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    public override func canBecomeFirstResponder() -> Bool {
        return true
    }

    public override var keyCommands: [UIKeyCommand]? {
        let addTitleToCmd: (UIKeyCommand, String) -> (Void) = {cmd, title in
            if #available(iOS 9.0, *) {
                cmd.discoverabilityTitle = title
            }
        }

        var commands: [UIKeyCommand] = []
        if self.lastArticleIndex != 0 {
            let cmd = UIKeyCommand(input: "p", modifierFlags: .Control, action: "showPreviousArticle")
            addTitleToCmd(cmd, NSLocalizedString("Previous article", comment: ""))
            commands.append(cmd)
        }

        if self.lastArticleIndex < (self.articles.count - 1) {
            let cmd = UIKeyCommand(input: "n", modifierFlags: .Control, action: "showNextArticle")
            addTitleToCmd(cmd, NSLocalizedString("Next article", comment: ""))
            commands.append(cmd)
        }

        let markAsRead = UIKeyCommand(input: "r", modifierFlags: .Shift, action: "toggleArticleRead")
        addTitleToCmd(markAsRead, NSLocalizedString("Toggle read", comment: ""))
        commands.append(markAsRead)

        if let _ = self.article?.link {
            let cmd = UIKeyCommand(input: "l", modifierFlags: .Command, action: "toggleContentLink")
            addTitleToCmd(cmd, NSLocalizedString("Toggle view content/link", comment: ""))
            commands.append(cmd)
        }

        let showShareSheet = UIKeyCommand(input: "s", modifierFlags: .Command, action: "share")
        addTitleToCmd(showShareSheet, NSLocalizedString("Open share sheet", comment: ""))
        commands.append(showShareSheet)

        return commands
    }

    internal func showPreviousArticle() {
        guard self.lastArticleIndex > 0 else {
            return
        }
        self.lastArticleIndex--
        self.article = self.articles[lastArticleIndex]
        if let article = self.article {
            self.showArticle(article, onWebView: self.content)
        }
    }

    internal func showNextArticle() {
        guard self.lastArticleIndex < self.articles.count else {
            return
        }
        self.lastArticleIndex++
        self.article = self.articles[lastArticleIndex]
        if let article = self.article {
            self.showArticle(article, onWebView: self.content)
        }
    }

    internal func toggleArticleRead() {
        guard let article = self.article else {
            return
        }
        self.dataWriter?.markArticle(article, asRead: !article.read)
    }

    private var objectsBeingObserved: [WKWebView] = []

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.userActivity?.invalidate()
        self.userActivity = nil
        for obj in self.objectsBeingObserved {
            obj.removeObserver(self, forKeyPath: "estimatedProgress")
        }
        self.objectsBeingObserved = []
    }

    private func removeObserverFromContent(obj: WKWebView) {
        var idx: Int? = nil
        repeat {
            idx = nil
            for (i, x) in self.objectsBeingObserved.enumerate() {
                if x == obj {
                    idx = i
                    x.removeObserver(self, forKeyPath: "estimatedProgress")
                    break
                }
            }
            if let i = idx {
                self.objectsBeingObserved.removeAtIndex(i)
            }
        } while idx != nil
    }

    deinit {
        for obj in self.objectsBeingObserved {
            obj.removeObserver(self, forKeyPath: "estimatedProgress")
        }
        self.objectsBeingObserved = []
        self.userActivity?.invalidate()
    }

    private func configureContent() {
        self.content.navigationDelegate = self
        self.view.bringSubviewToFront(self.loadingBar)
        if let items = self.navigationItem.rightBarButtonItems {
            let forward = items[0]
            let back = items[1]
            forward.enabled = content.canGoForward
            back.enabled = content.canGoBack
        }
    }

    private var nextContent: WKWebView? = nil
    private var nextContentRight: NSLayoutConstraint! = nil

    internal func next(gesture: UIScreenEdgePanGestureRecognizer) {
        if lastArticleIndex + 1 >= articles.count {
            return;
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width + gesture.translationInView(self.view).x
        if gesture.state == .Began {
            let a = articles[lastArticleIndex+1]
            self.nextContent = WKWebView(forAutoLayout: ())
            self.nextContent?.backgroundColor = self.themeRepository?.backgroundColor
            self.view.addSubview(self.nextContent!)
            self.showArticle(a, onWebView: self.nextContent!)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Top)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Bottom)
            self.nextContent?.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            self.nextContentRight = nextContent!.autoPinEdgeToSuperviewEdge(.Right, withInset: translation)
        } else if gesture.state == .Changed {
            self.nextContentRight.constant = translation
        } else if gesture.state == .Cancelled {
            self.nextContent?.removeFromSuperview()
            self.removeObserverFromContent(self.nextContent!)
            self.nextContent = nil
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x * -1
            if speed >= 0 {
                self.lastArticleIndex++
                self.article = articles[lastArticleIndex]
                self.nextContentRight.constant = 0
                let oldContent = content
                self.content = self.nextContent
                self.configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(completed) in
                    self.view.bringSubviewToFront(self.loadingBar)
                    oldContent.removeFromSuperview()
                    self.removeObserverFromContent(oldContent)
                })
            } else {
                self.nextContent?.removeFromSuperview()
                self.removeObserverFromContent(self.nextContent!)
                self.nextContent = nil
            }
        }
    }

    internal func share() {
        if let link = self.content.URL ?? article?.link {
            let safari = TOActivitySafari()
            let chrome = TOActivityChrome()

            let activity = UIActivityViewController(activityItems: [link],
                applicationActivities: [safari, chrome])
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: activity)
                popover.presentPopoverFromBarButtonItem(shareButton, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(activity, animated: true, completion: nil)
            }
        }
    }

    internal func toggleContentLink() {
        switch (self.contentType) {
        case .Link:
            self.contentType = .Content
            self.userActivity?.userInfo?["showingContent"] = true
        case .Content:
            self.contentType = .Link
            self.userActivity?.userInfo?["showingContent"] = false
        }
        self.userActivity?.needsSave = true
    }

    public override func observeValueForKeyPath(keyPath: String?,
        ofObject object: AnyObject?, change: [String : AnyObject]?,
        context: UnsafeMutablePointer<Void>) {
            if (keyPath == "estimatedProgress" && (object as? NSObject) == content) {
                self.loadingBar.progress = Float(content.estimatedProgress)
            }
    }

    public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        self.loadingBar.hidden = true
        self.removeObserverFromContent(webView)
        if webView.URL?.scheme != "about" {
            self.userActivity?.webpageURL = webView.URL
        }

        if let items = self.navigationItem.rightBarButtonItems, forward = items.first, back = items.last {
            forward.enabled = content.canGoForward
            back.enabled = content.canGoBack
        }
    }

    public func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError _: NSError) {
        self.loadingBar.hidden = true
        self.removeObserverFromContent(webView)
    }

    public func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.loadingBar.progress = 0
        self.loadingBar.hidden = false
        if !self.objectsBeingObserved.contains(webView) {
            webView.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
            self.objectsBeingObserved.append(webView)
        }
    }
}

extension ArticleViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.articleCSS = self.loadArticleCSS()
        self.content.reload()
        self.nextContent?.reload()

        self.content.backgroundColor = self.themeRepository?.backgroundColor
        self.nextContent?.backgroundColor = self.themeRepository?.backgroundColor

        self.navigationController?.navigationBar.barStyle = self.themeRepository?.theme == .Default ? .Default : .Black
        self.navigationController?.toolbar.barStyle = self.themeRepository?.theme == .Default ? .Default : .Black
    }
}
