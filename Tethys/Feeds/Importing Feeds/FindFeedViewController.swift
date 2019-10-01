import UIKit
import WebKit
import SafariServices
import Muon
import Lepton
import TethysKit

public final class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    public lazy var webContent = WKWebView(forAutoLayout: ())

    public let loadingBar = UIProgressView(progressViewStyle: .bar)
    public let navField = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
    fileprivate var rssLinks = [URL]()

    public var addFeedButton: UIBarButtonItem!
    public var back: UIBarButtonItem!
    public var forward: UIBarButtonItem!
    public var reload: UIBarButtonItem!
    public var cancelTextEntry: UIBarButtonItem!

    fileprivate let importUseCase: ImportUseCase
    fileprivate let analytics: Analytics
    fileprivate let notificationCenter: NotificationCenter

    private let placeholderAttributes: [NSAttributedString.Key: AnyObject] = [
        NSAttributedString.Key.foregroundColor: Theme.textColor
    ]

    private var observer: NSKeyValueObservation?

    public init(importUseCase: ImportUseCase,
                analytics: Analytics,
                notificationCenter: NotificationCenter) {
        self.importUseCase = importUseCase
        self.analytics = analytics
        self.notificationCenter = notificationCenter
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = [.left, .right]

        self.webContent.navigationDelegate = self
        self.webContent.uiDelegate = self
        self.view.addSubview(self.webContent)
        self.webContent.autoPinEdgesToSuperviewEdges(with: .zero)
        self.observer = self.webContent.observe(\.estimatedProgress, options: [.new]) { _, _ in
            self.loadingBar.progress = Float(self.webContent.estimatedProgress)
        }

        let save = #selector(FindFeedViewController.save as (FindFeedViewController) -> () -> Void)
        self.addFeedButton = UIBarButtonItem(title: NSLocalizedString("FindFeedViewController_AddFeed", comment: ""),
                                             style: .plain, target: self, action: save)
        self.addFeedButton.isEnabled = false
        self.back = UIBarButtonItem(image: Image(named: "LeftChevron"), style: .plain, target: self.webContent,
                                    action: #selector(WKWebView.goBack))
        self.forward = UIBarButtonItem(image: Image(named: "RightChevron"), style: .plain, target: self.webContent,
                                       action: #selector(WKWebView.goForward))
        self.back.isEnabled = false
        self.forward.isEnabled = false

        self.reload = UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                      action: #selector(FindFeedViewController.reloadWebPage))

        let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
        self.cancelTextEntry = UIBarButtonItem(title: cancelTitle, style: .plain,
                                               target: self,
                                               action: #selector(FindFeedViewController.dismissNavFieldKeyboard))

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Generic_Close", comment: ""),
            style: .plain, target: self,
            action: #selector(FindFeedViewController.dismissFromNavigation)
        )

        self.navigationController?.isToolbarHidden = false
        func spacer() -> UIBarButtonItem {
            return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        }
        self.toolbarItems = [self.back, self.forward, spacer(), self.addFeedButton]

        self.navigationItem.titleView = self.navField
        self.navField.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width * 0.8, height: 32)
        self.navField.delegate = self
        let urlPlaceholder = NSLocalizedString("FindFeedViewController_URLBar_Placeholder", comment: "")
        self.navField.attributedPlaceholder = NSAttributedString(string: urlPlaceholder,
                                                                 attributes: self.placeholderAttributes)
        self.navField.layer.cornerRadius = 4
        self.navField.autocorrectionType = .no
        self.navField.autocapitalizationType = .none
        self.navField.keyboardType = .URL
        self.navField.clearsOnBeginEditing = true
        self.navField.textContentType = .URL

        self.loadingBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.loadingBar)
        self.loadingBar.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.loadingBar.autoSetDimension(.height, toSize: 1)
        self.loadingBar.progress = 0
        self.loadingBar.isHidden = true

        self.applyTheme()

        self.analytics.logEvent("DidViewWebImport", data: nil)
    }

    private func applyTheme() {
        self.webContent.backgroundColor = Theme.backgroundColor
        self.view.backgroundColor = Theme.backgroundColor
        self.loadingBar.progressTintColor = Theme.progressTintColor
        self.loadingBar.trackTintColor = Theme.progressTrackColor

        self.navField.backgroundColor = UIColor.secondarySystemFill
        self.navField.textColor = Theme.textColor
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.focusNavField()
    }

    public override func viewWillTransition(to size: CGSize,
                                            with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.navField.frame = CGRect(x: 0, y: 0, width: size.width * 0.8, height: 32)
    }

    public override var canBecomeFirstResponder: Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {

        let focusNavField = UIKeyCommand(input: "l", modifierFlags: [],
                                         action: #selector(FindFeedViewController.focusNavField))
        let reloadContent = UIKeyCommand(input: "r", modifierFlags: [],
                                         action: #selector(FindFeedViewController.reloadWebPage))

        focusNavField.discoverabilityTitle =
            NSLocalizedString("FindFeedViewController_Commands_OpenURL", comment: "")
        reloadContent.discoverabilityTitle =
            NSLocalizedString("FindFeedViewController_Commands_Reload", comment: "")

        var commands = [focusNavField, reloadContent]

        if !self.rssLinks.isEmpty {
            let selector = #selector(FindFeedViewController.save as (FindFeedViewController) -> () -> Void)
            let importFeed = UIKeyCommand(input: "i", modifierFlags: [], action: selector)
            importFeed.discoverabilityTitle =
                NSLocalizedString("FindFeedViewController_FoundFeed_Import", comment: "")
            commands.append(importFeed)
        }

        return commands
    }

    // MARK: - UITextFieldDelegate

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.navigationItem.setRightBarButton(self.cancelTextEntry, animated: true)
        textField.text = self.webContent.url?.absoluteString
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        let button: UIBarButtonItem? = self.webContent.estimatedProgress >= 1.0 ? self.reload : nil
        self.navigationItem.setRightBarButton(button, animated: true)
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let whitespace = CharacterSet.whitespacesAndNewlines
        textField.text = textField.text?.trimmingCharacters(in: whitespace)
        let originalText = textField.text ?? ""
        if originalText.lowercased().hasPrefix("http") == false {
            textField.text = "https://\(originalText)"
        }
        if let text = textField.text, let url = URL(string: text), text.contains(".") {
            self.webContent.load(URLRequest(url: url))
        } else if let url = URL(string: "https://duckduckgo.com/?q=" +
            originalText.replacingOccurrences(of: " ", with: "+")) {
            self.webContent.load(URLRequest(url: url))
        }
        let urlLoading = NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: "")
        textField.attributedPlaceholder = NSAttributedString(string: urlLoading,
                                                             attributes: self.placeholderAttributes)
        textField.resignFirstResponder()

        return true
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        self.loadingBar.isHidden = true
        self.navField.attributedPlaceholder = NSAttributedString(string: webView.title ?? "",
                                                                 attributes: self.placeholderAttributes)
        self.forward.isEnabled = webView.canGoForward
        self.back.isEnabled = webView.canGoBack
        self.navigationItem.rightBarButtonItem = self.reload
    }

    public func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        self.loadingBar.isHidden = true
        self.failedToLoadPage(error as NSError)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        self.loadingBar.isHidden = true
        self.failedToLoadPage(error as NSError)
    }

    private func failedToLoadPage(_ error: NSError) {
        let title = NSLocalizedString("FindFeedViewController_Error_Navigation_title", comment: "")
        let messageFormat = NSLocalizedString("FindFeedViewController_Error_Navigation_message", comment: "")
        let urlString = error.userInfo["NSErrorFailingURLStringKey"] as? String ?? ""
        let message = NSString.localizedStringWithFormat(messageFormat as NSString, urlString) as String

        let content = "<h1>\(title)</h1><span>\(message)</span>"

        self.webContent.loadHTMLString(self.staticHTML(title: title, content: content), baseURL: nil)
    }

    private func staticHTML(title: String, content: String) -> String {
        let prefix: String
        let cssFileName = Theme.articleCSSFileName
        if let cssURL = Bundle.main.url(forResource: cssFileName, withExtension: "css"),
            let css = try? String(contentsOf: cssURL) {
            prefix = "<html><head>" +
                "<title>\(title)</title>" +
                "<style type=\"text/css\">\(css)</style>" +
                "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
            "</head><body>"
        } else {
            prefix = "<html><body>"
        }

        let postfix = "</body></html>"

        return prefix + content + postfix
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        self.loadingBar.progress = 0
        self.loadingBar.isHidden = false
        self.navField.text = ""
        let urlLoading = NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: "")
        self.navField.attributedPlaceholder = NSAttributedString(string: urlLoading,
                                                                 attributes: self.placeholderAttributes)
        self.addFeedButton.isEnabled = false
        if let url = webView.url {
            self.importUseCase.scanForImportable(url).then { item in
                switch item {
                case .feed(let url, _):
                    self.askToImportFeed(url)
                case .webPage(_, let feeds):
                    if !feeds.isEmpty {
                        self.rssLinks = feeds
                        self.addFeedButton.isEnabled = true
                    }
                case .opml(let url, _):
                    self.askToImportOPML(url)
                default: break
                }
            }
        }
    }
}

extension FindFeedViewController: WKUIDelegate {
    public func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
                        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        guard let url = elementInfo.linkURL else {
            return completionHandler(nil)
        }

        completionHandler(UIContextMenuConfiguration(
            identifier: url as NSURL,
            previewProvider: {
                let controller = FindFeedViewController(importUseCase: self.importUseCase,
                                                        analytics: self.analytics,
                                                        notificationCenter: self.notificationCenter)
                _ = controller.view
                controller.webContent.load(URLRequest(url: url))
                return controller
        }, actionProvider: nil))
    }

    public func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo,
                        willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating) {
        guard let viewController = animator.previewViewController else { return }
        animator.addCompletion {
            self.navigationController?.setViewControllers([viewController], animated: true)
        }
    }
}

// MARK: Private
extension FindFeedViewController {
    @objc fileprivate func focusNavField() {
        self.navField.becomeFirstResponder()
        self.navField.selectAll(nil)
    }

    @objc fileprivate func reloadWebPage() { self.webContent.reload() }

    @objc fileprivate func dismissNavFieldKeyboard() {
        self.navField.resignFirstResponder()
        self.navField.text = nil
    }

    @objc fileprivate func dismissFromNavigation() {
        let presenter = self.presentingViewController ?? self.navigationController?.presentingViewController
        if let presentingController = presenter {
            presentingController.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc fileprivate func save() {
        if let rl = self.rssLinks.first, self.rssLinks.count == 1 {
            self.save(link: rl)
        } else if self.rssLinks.count > 1 {
            let alertTitle = NSLocalizedString("FindFeedViewController_ImportFeeds_SelectFeed", comment: "")
            let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .actionSheet)
            for link in self.rssLinks {
                let pathWithPrecedingSlash = link.path
                let index = pathWithPrecedingSlash.index(after: pathWithPrecedingSlash.startIndex)
                let path = String(pathWithPrecedingSlash[index...])
                alert.addAction(UIAlertAction(title: path, style: .default) { _ in
                    self.save(link: link)
                })
            }
            let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            self.dismissFromNavigation()
        }
    }

    fileprivate func save(link: URL, opml: Bool = false) {
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdges(with: .zero)

        let feedMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed", comment: "")
        let opmlMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed_List", comment: "")

        let messageTemplate = opml ? opmlMessageTemplate : feedMessageTemplate
        let message = NSString.localizedStringWithFormat(messageTemplate as NSString, link as CVarArg) as String
        indicator.configure(message: message)
        self.importUseCase.importItem(link).then { _ in
            indicator.removeFromSuperview()
            self.analytics.logEvent("DidUseWebImport", data: nil)
            self.dismissFromNavigation()
            self.notificationCenter.post(name: Notifications.reloadUI, object: self)
        }
    }

    fileprivate func askToImportFeed(_ url: URL) {
        let title = NSLocalizedString("FindFeedViewController_FoundFeed_Title", comment: "")
        let messageFormat = NSLocalizedString("FindFeedViewController_FoundFeed_Subtitle", comment: "")
        let message = String.localizedStringWithFormat(messageFormat, url.lastPathComponent)

        self.displayAlertToSave(title, alertMessage: message) { self.save(link: url, opml: false) }
    }

    fileprivate func askToImportOPML(_ url: URL) {
        let title = NSLocalizedString("FindFeedViewController_FoundFeed_List_Title", comment: "")
        let message = NSLocalizedString("FindFeedViewController_FoundFeed_List_Subtitle", comment: "")

        self.displayAlertToSave(title, alertMessage: message) { self.save(link: url, opml: true) }
    }

    fileprivate func displayAlertToSave(_ alertTitle: String, alertMessage: String, success: @escaping () -> Void) {
        let doNotSave = NSLocalizedString("FindFeedViewController_FoundFeed_Decline", comment: "")
        let save = NSLocalizedString("FindFeedViewController_FoundFeed_Import", comment: "")

        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: doNotSave, style: .cancel) {_ in
            alert.presentingViewController?.dismiss(animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: save, style: .default) {_ in
            alert.presentingViewController?.dismiss(animated: true, completion: nil)
            success()
        })
        self.present(alert, animated: true, completion: nil)
    }
}
