import UIKit
import WebKit
import Muon
import Lepton
import Ra
import rNewsKit

public class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate, Injectable {
    public lazy var webContent = WKWebView(forAutoLayout: ())

    public let loadingBar = UIProgressView(progressViewStyle: .Bar)
    public let navField = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
    private var rssLinks = [NSURL]()

    public var addFeedButton: UIBarButtonItem!
    public var back: UIBarButtonItem!
    public var forward: UIBarButtonItem!
    public var reload: UIBarButtonItem!
    public var cancelTextEntry: UIBarButtonItem!

    public var lookForFeeds = true

    private let importUseCase: ImportUseCase
    private let themeRepository: ThemeRepository

    private let placeholderAttributes: [String: AnyObject] = [NSForegroundColorAttributeName: UIColor.blackColor()]

    public init(importUseCase: ImportUseCase,
                themeRepository: ThemeRepository) {
        self.importUseCase = importUseCase
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            importUseCase: injector.create(ImportUseCase)!,
            themeRepository: injector.create(ThemeRepository)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None

        self.webContent.navigationDelegate = self
        self.view.addSubview(self.webContent)
        self.webContent.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)

        self.back = UIBarButtonItem(title: "<", style: .Plain, target: self.webContent,
                                    action: #selector(UIWebView.goBack))
        self.forward = UIBarButtonItem(title: ">", style: .Plain, target: self.webContent,
                                       action: #selector(UIWebView.goForward))

        let addFeedTitle = NSLocalizedString("FindFeedViewController_AddFeed", comment: "")
        let save = #selector(FindFeedViewController.save as (FindFeedViewController) -> () -> ())
        self.addFeedButton = UIBarButtonItem(title: addFeedTitle, style: .Plain, target: self, action: save)
        self.back.enabled = false
        self.forward.enabled = false
        self.addFeedButton.enabled = false

        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismiss = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self,
                                      action: #selector(FindFeedViewController.dismiss))
        self.reload = UIBarButtonItem(barButtonSystemItem: .Refresh, target: self,
                                      action: #selector(FindFeedViewController.reloadWebPage))

        let cancelTitle = NSLocalizedString("FindFeedViewController_Cancel", comment: "")
        self.cancelTextEntry = UIBarButtonItem(title: cancelTitle, style: .Plain,
            target: self, action: #selector(FindFeedViewController.dismissNavFieldKeyboard))

        self.navigationController?.toolbarHidden = false
        func spacer() -> UIBarButtonItem {
            return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: Selector())
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
        self.navField.autocorrectionType = .No
        self.navField.autocapitalizationType = .None
        self.navField.keyboardType = .URL
        self.navField.clearsOnBeginEditing = true

        self.loadingBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.loadingBar)
        self.loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        self.loadingBar.autoSetDimension(.Height, toSize: 1)
        self.loadingBar.progress = 0
        self.loadingBar.hidden = true
        self.loadingBar.progressTintColor = UIColor.darkGreenColor()

        self.themeRepository.addSubscriber(self)
    }

    deinit {
        self.webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }

    public override func viewWillTransitionToSize(size: CGSize,
        withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)

            self.navField.frame = CGRect(x: 0, y: 0, width: size.width * 0.8, height: 32)
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?,
        change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "estimatedProgress" && object as? NSObject == self.webContent {
            self.loadingBar.progress = Float(self.webContent.estimatedProgress)
        }
    }

    public override func canBecomeFirstResponder() -> Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {

        let focusNavField = UIKeyCommand(input: "l", modifierFlags: [],
                                         action: #selector(FindFeedViewController.focusNavField))
        let reloadContent = UIKeyCommand(input: "r", modifierFlags: [],
                                         action: #selector(FindFeedViewController.reloadWebPage))

        if #available(iOS 9.0, *) {
            focusNavField.discoverabilityTitle =
                NSLocalizedString("FindFeedViewController_Commands_OpenURL", comment: "")
            reloadContent.discoverabilityTitle =
                NSLocalizedString("FindFeedViewController_Commands_Reload", comment: "")
        }

        var commands = [focusNavField, reloadContent]

        if !self.rssLinks.isEmpty {
            let selector = #selector(FindFeedViewController.save as (FindFeedViewController) -> () -> ())
            let importFeed = UIKeyCommand(input: "i", modifierFlags: [], action: selector)
            if #available(iOS 9.0, *) {
                importFeed.discoverabilityTitle =
                    NSLocalizedString("FindFeedViewController_FoundFeed_Import", comment: "")
            }
            commands.append(importFeed)
        }

        return commands
    }

    // MARK: - UITextFieldDelegate

    public func textFieldDidBeginEditing(textField: UITextField) {
        self.navigationItem.setRightBarButtonItem(self.cancelTextEntry, animated: true)
        textField.text = self.webContent.URL?.absoluteString
    }

    public func textFieldDidEndEditing(textField: UITextField) {
        var button: UIBarButtonItem? = nil
        if self.webContent.estimatedProgress >= 1.0 {
            button = self.reload
        }
        self.navigationItem.setRightBarButtonItem(button, animated: true)
    }

    public func textFieldShouldReturn(textField: UITextField) -> Bool {
        let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        textField.text = textField.text?.stringByTrimmingCharactersInSet(whitespace)
        let originalText = textField.text ?? ""
        if originalText.lowercaseString.hasPrefix("http") == false {
            textField.text = "http://\(originalText)"
        }
        if let text = textField.text, url = NSURL(string: text) {
            self.webContent.loadRequest(NSURLRequest(URL: url))
        } else if let url = NSURL(string: "https://duckduckgo.com/?q=" +
                originalText.stringByReplacingOccurrencesOfString(" ", withString: "+")) {
            self.webContent.loadRequest(NSURLRequest(URL: url))
        }
        let urlLoading = NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: "")
        textField.attributedPlaceholder = NSAttributedString(string: urlLoading,
            attributes: self.placeholderAttributes)
        textField.resignFirstResponder()

        return true
    }

    // MARK: - WKNavigationDelegate

    public func webView(webView: WKWebView, didFinishNavigation _: WKNavigation!) {
        self.loadingBar.hidden = true
        self.navField.attributedPlaceholder = NSAttributedString(string: webView.title ?? "",
            attributes: self.placeholderAttributes)
        self.forward.enabled = webView.canGoForward
        self.back.enabled = webView.canGoBack
        self.navigationItem.rightBarButtonItem = self.reload
    }

    public func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError error: NSError) {
        self.loadingBar.hidden = true
    }

    public func webView(webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: NSError) {
        self.loadingBar.hidden = true
    }

    public func webView(webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        self.loadingBar.progress = 0
        self.loadingBar.hidden = false
        self.navField.text = ""
        let urlLoading = NSLocalizedString("FindFeedViewController_URLBar_Loading", comment: "")
        self.navField.attributedPlaceholder = NSAttributedString(string: urlLoading,
            attributes: self.placeholderAttributes)
        self.addFeedButton.enabled = false
        if let url = webView.URL where lookForFeeds {
            self.importUseCase.scanForImportable(url) { item in
                switch item {
                case .Feed(let url, _):
                    self.askToImportFeed(url)
                case .WebPage(_, let feeds):
                    if !feeds.isEmpty {
                        self.rssLinks = feeds
                        self.addFeedButton.enabled = true
                    }
                case .OPML(let url, _):
                    self.askToImportOPML(url)
                default: break
                }
            }
        }
    }
}

// MARK: Private
extension FindFeedViewController {
    @objc private func focusNavField() {
        self.navField.becomeFirstResponder()

        self.navField.selectAll(nil)
    }

    @objc private func reloadWebPage() {
        self.webContent.reload()
    }

    @objc private func dismissNavFieldKeyboard() {
        self.navField.resignFirstResponder()

        self.navField.text = nil
    }

    @objc private func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    @objc private func save() {
        if let rl = self.rssLinks.first where self.rssLinks.count == 1 {
            self.save(rl)
        } else if self.rssLinks.count > 1 {
            // yay!
            let alertTitle = NSLocalizedString("FindFeedViewController_ImportFeeds_SelectFeed", comment: "")
            let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .Alert)
            for link in self.rssLinks {
                let pathWithPrecedingSlash = link.path ?? ""
                let path = pathWithPrecedingSlash.substringFromIndex(pathWithPrecedingSlash.startIndex.successor())
                alert.addAction(UIAlertAction(title: path, style: .Default) { _ in
                    self.save(link)
                    self.dismissViewControllerAnimated(true, completion: nil)
                })
            }
            let cancelTitle = NSLocalizedString("FindFeedViewController_Cancel", comment: "")
            alert.addAction(UIAlertAction(title: cancelTitle, style: .Cancel) { _ in
                self.dismissViewControllerAnimated(true, completion: nil)
            })
            self.presentViewController(alert, animated: true, completion: nil)
        } else {
            self.dismiss()
        }
    }

    private func save(link: NSURL, opml: Bool = false) {
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        let feedMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed", comment: "")
        let opmlMessageTemplate = NSLocalizedString("FindFeedViewController_Save_Feed_List", comment: "")

        let messageTemplate = opml ? opmlMessageTemplate : feedMessageTemplate
        let message = NSString.localizedStringWithFormat(messageTemplate, link) as String
        indicator.configureWithMessage(message)
        self.importUseCase.importItem(link) {
            indicator.removeFromSuperview()
            self.dismiss()
        }
    }

    private func askToImportFeed(url: NSURL) {
        let title = NSLocalizedString("FindFeedViewController_FoundFeed_Title", comment: "")
        let messageFormat = NSLocalizedString("FindFeedViewController_FoundFeed_Subtitle", comment: "")
        let message = String.localizedStringWithFormat(messageFormat, url.lastPathComponent ?? "")

        self.displayAlertToSave(title, alertMessage: message) {
            self.save(url, opml: false)
        }
    }

    private func askToImportOPML(url: NSURL) {
        let title = NSLocalizedString("FindFeedViewController_FoundFeed_List_Title", comment: "")
        let message = NSLocalizedString("FindFeedViewController_FoundFeed_List_Subtitle", comment: "")

        self.displayAlertToSave(title, alertMessage: message) {
            self.save(url, opml: true)
        }
    }

    private func displayAlertToSave(alertTitle: String, alertMessage: String, success: Void -> Void) {
        let doNotSave = NSLocalizedString("FindFeedViewController_FoundFeed_Decline", comment: "")
        let save = NSLocalizedString("FindFeedViewController_FoundFeed_Import", comment: "")

        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: doNotSave, style: .Cancel) {_ in
            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: save, style: .Default) {_ in
            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            success()
        })
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

extension FindFeedViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.toolbar.barStyle = themeRepository.barStyle

        self.webContent.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
        self.webContent.backgroundColor = themeRepository.backgroundColor
    }
}
