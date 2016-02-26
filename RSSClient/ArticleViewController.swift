import UIKit
import AVFoundation
import PureLayout
import TOBrowserActivityKit
import Ra
import rNewsKit
import SafariServices

public class ArticleViewController: UIViewController, Injectable {
    public private(set) var article: Article? = nil
    public func setArticle(article: Article?, read: Bool = true, show: Bool = true) {
        self.article = article

        guard let article = article else { return }
        if show { self.showArticle(article, onWebView: self.content) }

        self.userActivity = self.readArticleUseCase.userActivityForArticle(article)

        self.toolbarItems = [self.spacer(), self.shareButton, self.spacer()]
        if #available(iOS 9, *) {
            if article.link != nil {
                self.toolbarItems = [
                    self.spacer(), self.shareButton, self.spacer(), self.openInSafariButton, self.spacer()
                ]
            }
        }
        self.title = article.title
    }

    public var content = UIWebView(forAutoLayout: ())

    public let enclosuresList = EnclosuresList(frame: CGRect.zero)
    private var enclosuresListHeight: NSLayoutConstraint?

    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "share")
    }()
    public private(set) lazy var openInSafariButton: UIBarButtonItem = {
        return UIBarButtonItem(title: self.linkString, style: .Plain, target: self, action: "openInSafari")
    }()

    private let linkString = NSLocalizedString("ArticleViewController_TabBar_ViewLink", comment: "")

    public var articles = DataStoreBackedArray<Article>()
    public var lastArticleIndex = 0

    public let themeRepository: ThemeRepository
    public let urlOpener: UrlOpener
    private let readArticleUseCase: ReadArticleUseCase

    public lazy var panGestureRecognizer: ScreenEdgePanGestureRecognizer = {
        return ScreenEdgePanGestureRecognizer(target: self, action: "didSwipe:")
    }()

    public init(themeRepository: ThemeRepository,
                urlOpener: UrlOpener,
                readArticleUseCase: ReadArticleUseCase) {
        self.themeRepository = themeRepository
        self.urlOpener = urlOpener
        self.readArticleUseCase = readArticleUseCase

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            urlOpener: injector.create(UrlOpener)!,
            readArticleUseCase: injector.create(ReadArticleUseCase)!
        )
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func showArticle(article: Article, onWebView webView: UIWebView) {
        webView.loadHTMLString(self.readArticleUseCase.readArticle(article), baseURL: article.link)

        let enclosures = article.enclosuresArray.filter(enclosureIsSupported)
        self.view.layoutIfNeeded()
        if !enclosures.isEmpty {
            self.enclosuresListHeight?.constant = (enclosures.count == 1 ? 70 : 100)
        } else {
            self.enclosuresListHeight?.constant = 0
        }
        self.enclosuresList.configure(DataStoreBackedArray(enclosures), viewController: self)
        self.view.layoutIfNeeded()

        webView.scrollView.scrollIndicatorInsets.bottom = 0
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
    }

    public let backgroundView: UIView = {
        let view = UIView(forAutoLayout: ())

        return view
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = self.themeRepository.backgroundColor
        self.navigationController?.setToolbarHidden(false, animated: false)

        self.view.addGestureRecognizer(self.panGestureRecognizer)
        self.view.addSubview(self.content)
        self.view.addSubview(self.enclosuresList)
        self.view.addSubview(self.backgroundView)

        self.content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        self.content.autoPinEdge(.Bottom, toEdge: .Top, ofView: self.enclosuresList)
        self.enclosuresList.autoPinEdgeToSuperviewEdge(.Leading)
        self.enclosuresList.autoPinEdgeToSuperviewEdge(.Trailing)
        self.view.addConstraint(NSLayoutConstraint(item: self.enclosuresList, attribute: .Bottom, relatedBy: .Equal,
            toItem: self.bottomLayoutGuide, attribute: .Top, multiplier: 1, constant: 0))
        self.enclosuresListHeight = self.enclosuresList.autoSetDimension(.Height, toSize: 0)

        self.updateLeftBarButtonItem(self.traitCollection)

        self.backgroundView.autoPinEdgesToSuperviewEdges()

        self.themeRepository.addSubscriber(self)
        self.enclosuresList.themeRepository = self.themeRepository
        self.configureContent()
    }

    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: false)
        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.themeRepositoryDidChangeTheme(themeRepository)
        if self.article != nil { self.backgroundView.hidden = false }
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.userActivity?.invalidate()
        self.userActivity = nil
    }

    private func updateLeftBarButtonItem(traitCollection: UITraitCollection) {
        if traitCollection.horizontalSizeClass == .Regular {
            self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }
    }

    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateLeftBarButtonItem(self.traitCollection)
    }

    public override func canBecomeFirstResponder() -> Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        let addTitleToCmd: (UIKeyCommand, String) -> Void = {cmd, title in
            if #available(iOS 9, *) { cmd.discoverabilityTitle = title }
        }

        var commands: [UIKeyCommand] = []
        if self.lastArticleIndex != 0 {
            let cmd = UIKeyCommand(input: "p", modifierFlags: .Control, action: "showPreviousArticle")
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_ViewPreviousArticle", comment: ""))
            commands.append(cmd)
        }

        if self.lastArticleIndex < (self.articles.count - 1) {
            let cmd = UIKeyCommand(input: "n", modifierFlags: .Control, action: "showNextArticle")
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_ViewNextArticle", comment: ""))
            commands.append(cmd)
        }

        let markAsRead = UIKeyCommand(input: "r", modifierFlags: .Shift, action: "toggleArticleRead")
        addTitleToCmd(markAsRead, NSLocalizedString("ArticleViewController_Command_ToggleRead", comment: ""))
        commands.append(markAsRead)

        if let _ = self.article?.link {
            let cmd = UIKeyCommand(input: "l", modifierFlags: .Command, action: "openInSafari")
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_OpenInWebView", comment: ""))
            commands.append(cmd)
        }

        let showShareSheet = UIKeyCommand(input: "s", modifierFlags: .Command, action: "share")
        addTitleToCmd(showShareSheet, NSLocalizedString("ArticleViewController_Command_OpenShareSheet", comment: ""))
        commands.append(showShareSheet)

        return commands
    }

    @objc private func showPreviousArticle() {
        guard self.lastArticleIndex > 0 else { return }
        self.lastArticleIndex--
        self.setArticle(self.articles[lastArticleIndex])
        if let article = self.article { self.showArticle(article, onWebView: self.content) }
    }

    @objc private func showNextArticle() {
        guard self.lastArticleIndex < self.articles.count else { return }
        self.lastArticleIndex++
        self.setArticle(self.articles[lastArticleIndex])
        if let article = self.article { self.showArticle(article, onWebView: self.content) }
    }

    @objc private func toggleArticleRead() {
        guard let article = self.article else { return }
        self.readArticleUseCase.toggleArticleRead(article)
    }

    private func configureContent() {
        self.content.delegate = self
        self.content.scalesPageToFit = true
        self.content.opaque = false
        self.setThemeForWebView(self.content)
        if #available(iOS 9, *) { self.content.allowsLinkPreview = true }
    }

    private func setThemeForWebView(webView: UIWebView) {
        webView.backgroundColor = themeRepository.backgroundColor
        webView.scrollView.backgroundColor = themeRepository.backgroundColor
        webView.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }

    private var nextContent: UIWebView? = nil
    private var nextContentRight: NSLayoutConstraint? = nil

    private func handleSwipe(gesture: ScreenEdgePanGestureRecognizer, fromLeftDirection left: Bool) {
        if left && self.lastArticleIndex == 0 { return }
        if !left && (self.lastArticleIndex + 1) >= self.articles.count { return }

        let offset = left ? -1 : 1

        let width = self.view.bounds.width
        let translation = CGFloat(offset) * width + gesture.translationInView(self.view).x
        let nextArticleIndex = self.lastArticleIndex + offset
        if gesture.state == .Began {
            let a = self.articles[nextArticleIndex]
            self.nextContent = UIWebView(forAutoLayout: ())
            self.nextContent?.backgroundColor = self.themeRepository.backgroundColor
            self.nextContent?.scrollView.contentInset = self.content.scrollView.contentInset
            self.view.addSubview(self.nextContent!)
            self.showArticle(a, onWebView: self.nextContent!)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Top)
            self.nextContent?.autoPinEdge(.Bottom, toEdge: .Top, ofView: self.enclosuresList)
            self.nextContent?.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            let edge: ALEdge = left ? .Leading : .Trailing
            self.nextContentRight = self.nextContent!.autoPinEdgeToSuperviewEdge(edge, withInset: translation)
        } else if gesture.state == .Changed {
            self.nextContentRight?.constant = translation
        } else if gesture.state == .Cancelled {
            self.nextContent?.removeFromSuperview()
            self.nextContent = nil
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x * CGFloat(-offset)
            if speed >= 0 {
                self.lastArticleIndex = nextArticleIndex
                self.setArticle(self.articles[self.lastArticleIndex], show: false)
                self.nextContentRight?.constant = 0
                let oldContent = content
                if let nextContent = self.nextContent {
                    self.content = nextContent
                }
                self.configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                    }, completion: {_ in
                        oldContent.removeFromSuperview()
                })
            } else {
                self.nextContent?.removeFromSuperview()
                self.nextContent = nil
            }
        }
    }

    private func didSwipeFromLeft(gesture: ScreenEdgePanGestureRecognizer) {
        self.handleSwipe(gesture, fromLeftDirection: true)
    }

    private func didSwipeFromRight(gesture: ScreenEdgePanGestureRecognizer) {
        self.handleSwipe(gesture, fromLeftDirection: false)
    }

    @objc private func didSwipe(gesture: ScreenEdgePanGestureRecognizer) {
        switch gesture.startDirection {
        case .None: return
        case .Left: self.didSwipeFromLeft(gesture)
        case .Right: self.didSwipeFromRight(gesture)
        }
    }

    @objc private func share() {
        guard let link = self.article?.link else { return }
        let safari = TOActivitySafari()
        let chrome = TOActivityChrome()

        let activity = UIActivityViewController(activityItems: [link],
            applicationActivities: [safari, chrome])
        self.presentViewController(activity, animated: true, completion: nil)
    }

    @objc private func openInSafari() {
        guard let url = self.article?.link else { return }
        self.openURL(url)
    }

    private func openURL(url: NSURL) {
        if #available(iOS 9, *) { self.loadUrlInSafari(url)
        } else { self.urlOpener.openURL(url) }
    }

    private func loadUrlInSafari(url: NSURL) {
        guard #available(iOS 9, *) else { return }
        let safari = SFSafariViewController(URL: url)
        self.presentViewController(safari, animated: true, completion: nil)
    }
}

extension ArticleViewController: UIWebViewDelegate {
    public func webView(webView: UIWebView,
        shouldStartLoadWithRequest request: NSURLRequest,
        navigationType: UIWebViewNavigationType) -> Bool {
            guard let url = request.URL where navigationType == .LinkClicked else { return true }
            self.openURL(url)
            return false
    }

    public func webViewDidFinishLoad(webView: UIWebView) {
        self.backgroundView.hidden = self.article != nil
    }
}

extension ArticleViewController: NSUserActivityDelegate {
    public func userActivityWillSave(userActivity: NSUserActivity) {
        guard let article = self.article else { return }
        userActivity.userInfo = [
            "feed": article.feed?.title ?? "",
            "article": article.identifier,
        ]
    }
}

extension ArticleViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        if let article = self.article {
            self.showArticle(article, onWebView: self.content)
        }

        self.setThemeForWebView(self.content)
        if let nextContent = self.nextContent { self.setThemeForWebView(nextContent) }

        self.view.backgroundColor = themeRepository.backgroundColor
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.toolbar.barStyle = themeRepository.barStyle
        self.backgroundView.backgroundColor = themeRepository.backgroundColor
    }
}
