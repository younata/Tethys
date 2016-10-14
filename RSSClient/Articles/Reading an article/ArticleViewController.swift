import UIKit
import AVFoundation
import PureLayout
import TOBrowserActivityKit
import Ra
import rNewsKit
import WebKit
import SafariServices

public final class ArticleViewController: UIViewController, Injectable {
    public private(set) var article: Article? = nil
    public func setArticle(_ article: Article?, read: Bool = true, show: Bool = true) {
        self.article = article

        if let _ = article {
            self.backgroundSpinnerView.startAnimating()
        } else {
            self.backgroundSpinnerView.stopAnimating()
        }

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

    public var content = WKWebView(forAutoLayout: ())

    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .action, target: self,
                               action: #selector(ArticleViewController.share))
    }()
    public private(set) lazy var openInSafariButton: UIBarButtonItem = {
        return UIBarButtonItem(title: self.linkString, style: .plain,
                               target: self, action: #selector(ArticleViewController.openInSafari))
    }()

    private let linkString = NSLocalizedString("ArticleViewController_TabBar_ViewLink", comment: "")

    public let themeRepository: ThemeRepository
    fileprivate let articleUseCase: ArticleUseCase
    fileprivate let articleListController: (Void) -> ArticleListController

    public init(themeRepository: ThemeRepository,
                articleUseCase: ArticleUseCase,
                articleListController: @escaping (Void) -> ArticleListController) {
        self.themeRepository = themeRepository
        self.articleUseCase = articleUseCase
        self.articleListController = articleListController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            articleUseCase: injector.create(kind: ArticleUseCase.self)!,
            articleListController: { injector.create(kind: ArticleListController.self)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func showArticle(_ article: Article, onWebView webView: WKWebView) {
        webView.loadHTMLString(self.articleUseCase.readArticle(article), baseURL: article.link)

        self.view.layoutIfNeeded()

        webView.scrollView.scrollIndicatorInsets.bottom = 0
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    public private(set) lazy var backgroundSpinnerView: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: self.themeRepository.spinnerStyle)
        spinner.translatesAutoresizingMaskIntoConstraints = false
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
        self.view.addSubview(self.backgroundView)
        if let _ = self.article {
            self.backgroundSpinnerView.startAnimating()
        } else {
            self.backgroundSpinnerView.stopAnimating()
        }

        self.content.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .bottom)
        self.view.addConstraint(NSLayoutConstraint(item: self.content, attribute: .bottom, relatedBy: .equal,
            toItem: self.bottomLayoutGuide, attribute: .top, multiplier: 1, constant: 0))

        self.updateLeftBarButtonItem(self.traitCollection)

        self.backgroundView.autoPinEdgesToSuperviewEdges()

        self.themeRepository.addSubscriber(self)
        self.configureContent()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = true
        self.navigationController?.hidesBarsOnTap = true
        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.themeRepositoryDidChangeTheme(themeRepository)
        if self.article != nil { self.backgroundView.isHidden = false }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.userActivity?.invalidate()
        self.userActivity = nil

        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = false
    }

    private func updateLeftBarButtonItem(_ traitCollection: UITraitCollection) {
        if traitCollection.horizontalSizeClass == .regular {
            self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
            self.navigationItem.leftItemsSupplementBackButton = true
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateLeftBarButtonItem(self.traitCollection)
    }

    public override var canBecomeFirstResponder: Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        let addTitleToCmd: (UIKeyCommand, String) -> Void = {cmd, title in
            cmd.discoverabilityTitle = title
        }

        var commands: [UIKeyCommand] = []
        let markAsRead = UIKeyCommand(input: "r", modifierFlags: .shift,
                                      action: #selector(ArticleViewController.toggleArticleRead))
        addTitleToCmd(markAsRead, NSLocalizedString("ArticleViewController_Command_ToggleRead", comment: ""))
        commands.append(markAsRead)

        if let _ = self.article?.link {
            let cmd = UIKeyCommand(input: "l", modifierFlags: .command,
                                   action: #selector(ArticleViewController.openInSafari))
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_OpenInWebView", comment: ""))
            commands.append(cmd)
        }

        let showShareSheet = UIKeyCommand(input: "s", modifierFlags: .command,
                                          action: #selector(ArticleViewController.share))
        addTitleToCmd(showShareSheet, NSLocalizedString("ArticleViewController_Command_OpenShareSheet", comment: ""))
        commands.append(showShareSheet)

        return commands
    }

    var _previewActionItems: [UIPreviewAction] = []
    public override var previewActionItems: [UIPreviewActionItem] {
        return self._previewActionItems
    }

    @objc fileprivate func toggleArticleRead() {
        guard let article = self.article else { return }
        self.articleUseCase.toggleArticleRead(article)
    }

    private func configureContent() {
        self.content.navigationDelegate = self
        self.content.uiDelegate = self
        self.content.uiDelegate = self
        self.content.isOpaque = false
        self.setThemeForWebView(self.content)
        self.content.allowsLinkPreview = true

        var scriptContent = "var meta = document.createElement('meta');"
        scriptContent += "meta.name='viewport';"
        scriptContent += "meta.content='width=device-width';"
        scriptContent += "document.getElementsByTagName('head')[0].appendChild(meta);"

        self.content.evaluateJavaScript(scriptContent, completionHandler: nil)
    }

    fileprivate func setThemeForWebView(_ webView: WKWebView) {
        webView.backgroundColor = themeRepository.backgroundColor
        webView.scrollView.backgroundColor = themeRepository.backgroundColor
        webView.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }

    @objc fileprivate func share() {
        guard let article = self.article, let link = article.link else { return }
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
            if activityType == authorActivity.activityType, let author = article.authors.first {
                self.articleUseCase.articlesByAuthor(author) {
                    let articleListController = self.articleListController()
                    articleListController.articles = $0
                    articleListController.title = article.authors.first?.description
                    self.show(articleListController, sender: self)
                }
            }
        }
        self.present(activity, animated: true, completion: nil)
    }

    @objc private func openInSafari() {
        if let url = self.article?.link { self.openURL(url) }
    }

    fileprivate func openURL(_ url: URL) {
        self.loadUrlInSafari(url)
    }

    private func loadUrlInSafari(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        self.present(safari, animated: true, completion: nil)
    }
}

extension ArticleViewController: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        let navigationType = navigationAction.navigationType
        guard let url = request.url, navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }
        let predicate = NSPredicate(format: "link = %@", url.absoluteString)
        if let article = self.article?.relatedArticles.filterWithPredicate(predicate).first {
            let articleController = ArticleViewController(themeRepository: self.themeRepository,
                                                          articleUseCase: self.articleUseCase,
                                                          articleListController: self.articleListController)
            articleController.setArticle(article, read: true, show: true)
            self.navigationController?.pushViewController(articleController, animated: true)
        } else { self.openURL(url) }
        decisionHandler(.cancel)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.backgroundView.isHidden = self.article != nil
    }

    public func webView(_ webView: WKWebView,
                        previewingViewControllerForElement elementInfo: WKPreviewElementInfo,
                        defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
        guard let url = elementInfo.linkURL else { return nil }
        let predicate = NSPredicate(format: "link = %@", url.absoluteString)
        if let article = self.article?.relatedArticles.filterWithPredicate(predicate).first {
            let articleController = ArticleViewController(themeRepository: self.themeRepository,
                                                          articleUseCase: self.articleUseCase,
                                                          articleListController: self.articleListController)
            articleController.setArticle(article, read: true, show: true)
            return articleController
        } else {
            return SFSafariViewController(url: url)
        }
    }

    public func webView(_ webView: WKWebView,
                        commitPreviewingViewController previewingViewController: UIViewController) {
        if let _ = previewingViewController as? SFSafariViewController {
            self.present(previewingViewController, animated: true, completion: nil)
        } else {
            self.navigationController?.pushViewController(previewingViewController, animated: true)
        }
    }
}

extension ArticleViewController: NSUserActivityDelegate {
    public func userActivityWillSave(_ userActivity: NSUserActivity) {
        guard let article = self.article else { return }
        userActivity.userInfo = ["feed": article.feed?.title ?? "", "article": article.identifier]
    }
}

extension ArticleViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
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
