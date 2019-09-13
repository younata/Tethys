import UIKit
import PureLayout
import TOBrowserActivityKit
import TethysKit
import WebKit
import SafariServices

public final class ArticleViewController: UIViewController {
    public let article: Article

    public private(set) lazy var shareButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .action, target: self,
                                     action: #selector(ArticleViewController.share))
        button.accessibilityIdentifier = "ArticleViewController_ShareArticle"
        button.accessibilityLabel = String.localizedStringWithFormat(
            NSLocalizedString("ArticleViewController_Action_Accessibility_ShareArticle", comment: ""),
            self.article.title
        )
        button.isAccessibilityElement = true
        return button
    }()
    public private(set) lazy var openInSafariButton: UIBarButtonItem = {
        return UIBarButtonItem(title: self.linkString, style: .plain,
                               target: self, action: #selector(ArticleViewController.openInSafari))
    }()

    private let linkString = NSLocalizedString("ArticleViewController_TabBar_ViewLink", comment: "")

    fileprivate let articleUseCase: ArticleUseCase
    fileprivate let htmlViewController: HTMLViewController

    public init(article: Article,
                articleUseCase: ArticleUseCase,
                htmlViewController: @escaping () -> HTMLViewController) {
        self.article = article
        self.articleUseCase = articleUseCase
        self.htmlViewController = htmlViewController()

        super.init(nibName: nil, bundle: nil)

        self.htmlViewController.delegate = self
        self.addChild(self.htmlViewController)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func showArticle(_ article: Article) {
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

        self.toolbarItems = [
            self.spacer(), self.shareButton, self.spacer(), self.openInSafariButton, self.spacer()
        ]
        self.title = self.article.title

        self.view.backgroundColor = Theme.backgroundColor
        self.showArticle(self.article)
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

        let cmd = UIKeyCommand(input: "l", modifierFlags: .command,
                               action: #selector(ArticleViewController.openInSafari))
        addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_OpenInWebView", comment: ""))
        commands.append(cmd)

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
        self.articleUseCase.toggleArticleRead(self.article)
    }

    @objc fileprivate func share() {
        let safari = TOActivitySafari()
        let chrome = TOActivityChrome()

        let activity = URLShareSheet(
            url: self.article.link,
            activityItems: [self.article.link],
            applicationActivities: [safari, chrome]
        )
        activity.popoverPresentationController?.barButtonItem = self.shareButton

        self.present(activity, animated: true, completion: nil)
    }

    @objc private func openInSafari() {
        self.openURL(self.article.link)
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
        guard ["http", "https"].contains(url.scheme ?? "") else {
            return false
        }
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
