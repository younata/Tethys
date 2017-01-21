import UIKit
import WebKit
import SafariServices
import Muon
import Lepton
import Ra
import TethysKit

public final class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate, Injectable {
    public lazy var webContent = WKWebView(forAutoLayout: ())

    public let loadingBar = UIProgressView(progressViewStyle: .bar)
    public let navField = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
    fileprivate var rssLinks = [URL]()

    public var addFeedButton: UIBarButtonItem!
    public var back: UIBarButtonItem!
    public var forward: UIBarButtonItem!
    public var reload: UIBarButtonItem!
    public var cancelTextEntry: UIBarButtonItem!

    public var lookForFeeds = true

    fileprivate let importUseCase: ImportUseCase
    fileprivate let themeRepository: ThemeRepository
    fileprivate let analytics: Analytics

    private let placeholderAttributes: [String: AnyObject] = [NSForegroundColorAttributeName: UIColor.black]

    public init(importUseCase: ImportUseCase,
                themeRepository: ThemeRepository,
                analytics: Analytics) {
        self.importUseCase = importUseCase
        self.themeRepository = themeRepository
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            importUseCase: injector.create(kind: ImportUseCase.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            analytics: injector.create(kind: Analytics.self)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = UIRectEdge()

        self.webContent.navigationDelegate = self
        self.webContent.uiDelegate = self
        self.view.addSubview(self.webContent)
        self.webContent.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        self.webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)

        self.back = UIBarButtonItem(title: "<", style: .plain, target: self.webContent,
                                    action: #selector(UIWebView.goBack))
        self.forward = UIBarButtonItem(title: ">", style: .plain, target: self.webContent,
                                       action: #selector(UIWebView.goForward))

        let addFeedTitle = NSLocalizedString("FindFeedViewController_AddFeed", comment: "")
        let save = #selector(FindFeedViewController.save as (FindFeedViewController) -> (Void) -> Void)
        self.addFeedButton = UIBarButtonItem(title: addFeedTitle, style: .plain, target: self, action: save)
        self.back.isEnabled = false
        self.forward.isEnabled = false
        self.addFeedButton.isEnabled = false

        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismiss = UIBarButtonItem(title: dismissTitle, style: .plain, target: self,
                                      action: #selector(FindFeedViewController.dismissFromNavigation))
        self.reload = UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                      action: #selector(FindFeedViewController.reloadWebPage))

        let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
        self.cancelTextEntry = UIBarButtonItem(title: cancelTitle, style: .plain,
            target: self, action: #selector(FindFeedViewController.dismissNavFieldKeyboard))

        self.navigationController?.isToolbarHidden = false
        func spacer() -> UIBarButtonItem {
            return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        }
        if self.lookForFeeds {
            self.toolbarItems = [self.back, self.forward, spacer(), dismiss, spacer(), self.addFeedButton]
        } else {
            self.toolbarItems = [self.back, self.forward, spacer(), dismiss]
        }

        self.navigationItem.titleView = self.navField
        self.navField.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width * 0.8, height: 32)
        self.navField.delegate = self
        let urlPlaceholder = NSLocalizedString("FindFeedViewController_URLBar_Placeholder", comment: "")
        self.navField.attributedPlaceholder = NSAttributedString(string: urlPlaceholder,
            attributes: self.placeholderAttributes)
        self.navField.backgroundColor = UIColor(white: 0.8, alpha: 0.75)
        self.navField.layer.cornerRadius = 5
        self.navField.autocorrectionType = .no
        self.navField.autocapitalizationType = .none
        self.navField.keyboardType = .URL
        self.navField.clearsOnBeginEditing = true
        if #available(iOS 10.0, *) {
            self.navField.textContentType = .URL
        }

        self.loadingBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.loadingBar)
        self.loadingBar.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .bottom)
        self.loadingBar.autoSetDimension(.height, toSize: 1)
        self.loadingBar.progress = 0
        self.loadingBar.isHidden = true
        self.loadingBar.progressTintColor = UIColor.darkGreen()

        self.themeRepository.addSubscriber(self)

        self.analytics.logEvent("DidViewWebImport", data: nil)
    }

    deinit {
        self.webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    public override func viewWillTransition(to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)

            self.navField.frame = CGRect(x: 0, y: 0, width: size.width * 0.8, height: 32)
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" && object as? NSObject == self.webContent {
            self.loadingBar.progress = Float(self.webContent.estimatedProgress)
        }
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
            let selector = #selector(FindFeedViewController.save as (FindFeedViewController) -> (Void) -> Void)
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
        var button: UIBarButtonItem? = nil
        if self.webContent.estimatedProgress >= 1.0 {
            button = self.reload
        }
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
        let alertTitle = NSLocalizedString("FindFeedViewController_Error_Navigation_title", comment: "")
        let alertMessageFormat = NSLocalizedString("FindFeedViewController_Error_Navigation_message", comment: "")
        let urlString = error.userInfo["NSErrorFailingURLStringKey"] as? String ?? ""
        let alertMessage = NSString.localizedStringWithFormat(alertMessageFormat as NSString, urlString) as String
        let alert = UIAlertController(title: alertTitle,
                                      message: alertMessage,
                                      preferredStyle: .alert)
        let dismiss = NSLocalizedString("Generic_Ok", comment: "")
        alert.addAction(UIAlertAction(title: dismiss, style: .default) { _ in
            self.dismiss(animated: true, completion: nil)
        })
        self.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        self.loadingBar.progress = 0
        self.loadingBar.isHidden = false
        self.navField.text = ""
        let urlLoading = NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: "")
        self.navField.attributedPlaceholder = NSAttributedString(string: urlLoading,
            attributes: self.placeholderAttributes)
        self.addFeedButton.isEnabled = false
        if let url = webView.url, lookForFeeds {
            _ = self.importUseCase.scanForImportable(url).then { item in
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
    public func webView(_ webView: WKWebView,
                        previewingViewControllerForElement elementInfo: WKPreviewElementInfo,
                        defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
        if let url = elementInfo.linkURL {
            let controller = FindFeedViewController(importUseCase: self.importUseCase,
                                                    themeRepository: self.themeRepository,
                                                    analytics: self.analytics)
            _ = controller.view
            controller.webContent.load(URLRequest(url: url))
            return controller
        }
        return nil
    }

    public func webView(_ webView: WKWebView,
                        commitPreviewingViewController previewingViewController: UIViewController) {
        self.navigationController?.setViewControllers([previewingViewController], animated: true)
    }
}

// MARK: Private
extension FindFeedViewController {
    @objc fileprivate func focusNavField() {
        self.navField.becomeFirstResponder()
        self.navField.selectAll(nil)
    }

    @objc fileprivate func reloadWebPage() {
        self.webContent.reload()
    }

    @objc fileprivate func dismissNavFieldKeyboard() {
        self.navField.resignFirstResponder()
        self.navField.text = nil
    }

    @objc fileprivate func dismissFromNavigation() {
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc fileprivate func save() {
        if let rl = self.rssLinks.first, self.rssLinks.count == 1 {
            self.save(rl)
        } else if self.rssLinks.count > 1 {
            // yay!
            let alertTitle = NSLocalizedString("FindFeedViewController_ImportFeeds_SelectFeed", comment: "")
            let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .alert)
            for link in self.rssLinks {
                let pathWithPrecedingSlash = link.path
                let path = pathWithPrecedingSlash.substring(from:
                    pathWithPrecedingSlash.characters.index(after: pathWithPrecedingSlash.startIndex))
                alert.addAction(UIAlertAction(title: path, style: .default) { _ in
                    self.save(link)
                    self.dismiss(animated: true, completion: nil)
                })
            }
            let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                self.dismiss(animated: true, completion: nil)
            })
            self.present(alert, animated: true, completion: nil)
        } else {
            self.dismissFromNavigation()
        }
    }

    fileprivate func save(_ link: URL, opml: Bool = false) {
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        let feedMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed", comment: "")
        let opmlMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed_List", comment: "")

        let messageTemplate = opml ? opmlMessageTemplate : feedMessageTemplate
        let message = NSString.localizedStringWithFormat(messageTemplate as NSString, link as CVarArg) as String
        indicator.configure(message: message)
        _ = self.importUseCase.importItem(link).then { _ in
            indicator.removeFromSuperview()
            self.analytics.logEvent("DidUseWebImport", data: nil)
            self.dismissFromNavigation()
        }
    }

    fileprivate func askToImportFeed(_ url: URL) {
        let title = NSLocalizedString("FindFeedViewController_FoundFeed_Title", comment: "")
        let messageFormat = NSLocalizedString("FindFeedViewController_FoundFeed_Subtitle", comment: "")
        let message = String.localizedStringWithFormat(messageFormat, url.lastPathComponent)

        self.displayAlertToSave(title, alertMessage: message) {
            self.save(url, opml: false)
        }
    }

    fileprivate func askToImportOPML(_ url: URL) {
        let title = NSLocalizedString("FindFeedViewController_FoundFeed_List_Title", comment: "")
        let message = NSLocalizedString("FindFeedViewController_FoundFeed_List_Subtitle", comment: "")

        self.displayAlertToSave(title, alertMessage: message) {
            self.save(url, opml: true)
        }
    }

    fileprivate func displayAlertToSave(_ alertTitle: String, alertMessage: String, success: @escaping (Void) -> Void) {
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

extension FindFeedViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.toolbar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]

        self.webContent.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
        self.webContent.backgroundColor = themeRepository.backgroundColor
    }
}
