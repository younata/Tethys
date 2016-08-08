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

        self.backgroundSpinnerView.hidden = article == nil

        guard let article = article else { return }
        if show { self.showArticle(article, onWebView: self.content) }

        self.userActivity = self.articleUseCase.userActivityForArticle(article)

        self.toolbarItems = [self.spacer(), self.shareButton, self.spacer()]
        if let _ = article.link {
            self.toolbarItems = [
                self.spacer(), self.shareButton, self.spacer(), self.openInSafariButton, self.spacer()
            ]
        }
        self.title = article.title
    }

    public var content = UIWebView(forAutoLayout: ())

    public let enclosuresList = EnclosuresList(frame: CGRect.zero)
    private var enclosuresListHeight: NSLayoutConstraint?

    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Action, target: self,
                               action: #selector(ArticleViewController.share))
    }()
    public private(set) lazy var openInSafariButton: UIBarButtonItem = {
        return UIBarButtonItem(title: self.linkString, style: .Plain,
                               target: self, action: #selector(ArticleViewController.openInSafari))
    }()

    private let linkString = NSLocalizedString("ArticleViewController_TabBar_ViewLink", comment: "")

    public let themeRepository: ThemeRepository
    private let articleUseCase: ArticleUseCase
    private let articleListController: Void -> ArticleListController

    public init(themeRepository: ThemeRepository,
                articleUseCase: ArticleUseCase,
                articleListController: Void -> ArticleListController) {
        self.themeRepository = themeRepository
        self.articleUseCase = articleUseCase
        self.articleListController = articleListController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            articleUseCase: injector.create(ArticleUseCase)!,
            articleListController: { injector.create(ArticleListController)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func showArticle(article: Article, onWebView webView: UIWebView) {
        webView.loadHTMLString(self.articleUseCase.readArticle(article), baseURL: article.link)

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
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: Selector())
    }

    public private(set) lazy var backgroundSpinnerView: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: self.themeRepository.spinnerStyle)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        return spinner
    }()

    public private(set) lazy var backgroundView: UIView = {
        let view = UIView(forAutoLayout: ())

        view.addSubview(self.backgroundSpinnerView)
        self.backgroundSpinnerView.autoCenterInSuperview()

        return view
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = self.themeRepository.backgroundColor
        self.navigationController?.setToolbarHidden(false, animated: false)

        self.view.addSubview(self.content)
        self.view.addSubview(self.enclosuresList)
        self.view.addSubview(self.backgroundView)
        self.backgroundSpinnerView.hidden = article == nil

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
        self.navigationController?.hidesBarsOnSwipe = true
        self.navigationController?.hidesBarsOnTap = true
        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.themeRepositoryDidChangeTheme(themeRepository)
        if self.article != nil { self.backgroundView.hidden = false }
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.userActivity?.invalidate()
        self.userActivity = nil

        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = false
    }

    private func updateLeftBarButtonItem(traitCollection: UITraitCollection) {
        if traitCollection.horizontalSizeClass == .Regular {
            self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            self.navigationItem.leftItemsSupplementBackButton = true
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
            cmd.discoverabilityTitle = title
        }

        var commands: [UIKeyCommand] = []
        let markAsRead = UIKeyCommand(input: "r", modifierFlags: .Shift,
                                      action: #selector(ArticleViewController.toggleArticleRead))
        addTitleToCmd(markAsRead, NSLocalizedString("ArticleViewController_Command_ToggleRead", comment: ""))
        commands.append(markAsRead)

        if let _ = self.article?.link {
            let cmd = UIKeyCommand(input: "l", modifierFlags: .Command,
                                   action: #selector(ArticleViewController.openInSafari))
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_OpenInWebView", comment: ""))
            commands.append(cmd)
        }

        let showShareSheet = UIKeyCommand(input: "s", modifierFlags: .Command,
                                          action: #selector(ArticleViewController.share))
        addTitleToCmd(showShareSheet, NSLocalizedString("ArticleViewController_Command_OpenShareSheet", comment: ""))
        commands.append(showShareSheet)

        return commands
    }

    @objc private func toggleArticleRead() {
        guard let article = self.article else { return }
        self.articleUseCase.toggleArticleRead(article)
    }

    private func configureContent() {
        self.content.delegate = self
        self.content.scalesPageToFit = true
        self.content.opaque = false
        self.setThemeForWebView(self.content)
        self.content.allowsLinkPreview = true
    }

    private func setThemeForWebView(webView: UIWebView) {
        webView.backgroundColor = themeRepository.backgroundColor
        webView.scrollView.backgroundColor = themeRepository.backgroundColor
        webView.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }

    @objc private func share() {
        guard let article = self.article, link = article.link else { return }
        let safari = TOActivitySafari()
        let chrome = TOActivityChrome()

        let authorActivity: AuthorActivity?
        if let author = article.authors.first {
            authorActivity = AuthorActivity(author: author)
        } else { authorActivity = nil }

        var activities: [UIActivity] = [safari, chrome]
        if let activity = authorActivity { activities.append(activity) }

        let activity = UIActivityViewController(activityItems: [link],
            applicationActivities: activities)
        activity.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed, let authorActivity = authorActivity else { return }
            if activityType == authorActivity.activityType(), let author = article.authors.first {
                self.articleUseCase.articlesByAuthor(author) {
                    let articleListController = self.articleListController()
                    articleListController.articles = $0
                    articleListController.title = article.authors.first?.description
                    self.showViewController(articleListController, sender: self)
                }
            }
        }
        self.presentViewController(activity, animated: true, completion: nil)
    }

    @objc private func openInSafari() {
        if let url = self.article?.link { self.openURL(url) }
    }

    private func openURL(url: NSURL) {
        self.loadUrlInSafari(url)
    }

    private func loadUrlInSafari(url: NSURL) {
        let safari = SFSafariViewController(URL: url)
        self.presentViewController(safari, animated: true, completion: nil)
    }
}

extension ArticleViewController: UIWebViewDelegate {
    public func webView(webView: UIWebView,
        shouldStartLoadWithRequest request: NSURLRequest,
        navigationType: UIWebViewNavigationType) -> Bool {
            guard let url = request.URL where navigationType == .LinkClicked else { return true }
            let predicate = NSPredicate(format: "link = %@", url.absoluteString)
            if let article = self.article?.relatedArticles.filterWithPredicate(predicate).first {
                let articleController = ArticleViewController(themeRepository: self.themeRepository,
                                                              articleUseCase: self.articleUseCase,
                                                              articleListController: self.articleListController)
                articleController.setArticle(article, read: true, show: true)
                self.navigationController?.pushViewController(articleController, animated: true)
            } else { self.openURL(url) }
            return false
    }

    public func webViewDidFinishLoad(webView: UIWebView) { self.backgroundView.hidden = self.article != nil }
}

extension ArticleViewController: NSUserActivityDelegate {
    public func userActivityWillSave(userActivity: NSUserActivity) {
        guard let article = self.article else { return }
        userActivity.userInfo = ["feed": article.feed?.title ?? "", "article": article.identifier]
    }
}

extension ArticleViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        if let article = self.article {
            self.showArticle(article, onWebView: self.content)
        }

        self.setThemeForWebView(self.content)

        self.view.backgroundColor = themeRepository.backgroundColor
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.toolbar.barStyle = themeRepository.barStyle
        self.backgroundView.backgroundColor = themeRepository.backgroundColor
        self.backgroundSpinnerView.activityIndicatorViewStyle = themeRepository.spinnerStyle
    }
}
