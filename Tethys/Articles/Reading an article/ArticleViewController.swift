import UIKit
import PureLayout
import TOBrowserActivityKit
import TethysKit
import WebKit
import SafariServices

public final class ArticleViewController: UIViewController {
    public private(set) var article: Article?
    public func setArticle(_ article: Article?, read: Bool = true, show: Bool = true) {
        self.article = article

        guard let article = article else { return }
        if show { self.showArticle(article, read: read) }

        self.userActivity = self.articleUseCase.userActivityForArticle(article)

        self.toolbarItems = [
            self.spacer(), self.shareButton, self.spacer(), self.openInSafariButton, self.spacer()
        ]
        self.title = article.title
    }

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
    fileprivate let htmlViewController: HTMLViewController
    fileprivate let htmlViewControllerFactory: () -> HTMLViewController
    fileprivate let articleListController: () -> ArticleListController

    public init(themeRepository: ThemeRepository,
                articleUseCase: ArticleUseCase,
                htmlViewController: @escaping () -> HTMLViewController,
                articleListController: @escaping () -> ArticleListController) {
        self.themeRepository = themeRepository
        self.articleUseCase = articleUseCase
        self.htmlViewController = htmlViewController()
        self.htmlViewControllerFactory = htmlViewController
        self.articleListController = articleListController

        super.init(nibName: nil, bundle: nil)

        self.htmlViewController.delegate = self
        self.addChildViewController(self.htmlViewController)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func showArticle(_ article: Article, read: Bool = true) {
        self.htmlViewController.configure(html: self.articleUseCase.readArticle(article))
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.htmlViewController.view)
        self.htmlViewController.view.autoPinEdgesToSuperviewEdges()

        self.updateLeftBarButtonItem(self.traitCollection)

        self.themeRepository.addSubscriber(self)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = true
        self.navigationController?.hidesBarsOnTap = true
        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
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

    @objc fileprivate func share() {
        guard let article = self.article else { return }
        let safari = TOActivitySafari()
        let chrome = TOActivityChrome()

        let authorActivity: AuthorActivity?
        if let author = article.authors.first {
            authorActivity = AuthorActivity(author: author)
        } else { authorActivity = nil }

        var activities: [UIActivity] = [safari, chrome]
        if let activity = authorActivity { activities.append(activity) }

        let activity = URLShareSheet(
            url: article.link,
            themeRepository: self.themeRepository,
            activityItems: [article.link],
            applicationActivities: activities
        )
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

extension ArticleViewController: HTMLViewControllerDelegate {
    public func openURL(url: URL) -> Bool {
        self.openURL(url)
        return true
    }

    public func peekURL(url: URL) -> UIViewController? {
        return SFSafariViewController(url: url)
    }

    public func commitViewController(viewController: UIViewController) {
        if viewController is SFSafariViewController {
            self.present(viewController, animated: true, completion: nil)
        } else {
            self.navigationController?.pushViewController(viewController, animated: true)
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
            self.showArticle(article)
        }

        self.view.backgroundColor = themeRepository.backgroundColor
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.toolbar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]
    }
}
