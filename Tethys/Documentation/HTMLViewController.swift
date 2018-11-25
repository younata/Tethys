import UIKit
import PureLayout
import WebKit
import SafariServices

public protocol HTMLViewControllerDelegate: class {
    func openURL(url: URL) -> Bool
    func peekURL(url: URL) -> UIViewController?
    func commitViewController(viewController: UIViewController)
}

public final class HTMLViewController: UIViewController {
    public private(set) var htmlString: String?
    public weak var delegate: HTMLViewControllerDelegate?

    public func configure(html: String) {
        self.htmlString = html
        self.content.loadHTMLString(html, baseURL: nil)

        var scriptContent = "var meta = document.createElement('meta');"
        scriptContent += "meta.name='viewport';"
        scriptContent += "meta.content='width=device-width';"
        scriptContent += "document.getElementsByTagName('head')[0].appendChild(meta);"

        self.content.evaluateJavaScript(scriptContent, completionHandler: nil)
        self.progressIndicator.isHidden = false
    }

    public let content = WKWebView(forAutoLayout: ())
    public let progressIndicator = UIProgressView(forAutoLayout: ())

    private var observer: NSKeyValueObservation?

    public let themeRepository: ThemeRepository
    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)

        self.content.isOpaque = false
        self.observer = self.content.observe(\.estimatedProgress, options: [.new]) { _ in
            self.progressIndicator.progress = Float(self.content.estimatedProgress)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.observer = nil
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.content)
        self.view.addSubview(self.progressIndicator)

        self.content.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .bottom)
        self.view.addConstraint(NSLayoutConstraint(item: self.content, attribute: .bottom, relatedBy: .equal,
                                                   toItem: self.bottomLayoutGuide, attribute: .top,
                                                   multiplier: 1, constant: 0))

        self.view.addConstraint(NSLayoutConstraint(item: self.progressIndicator, attribute: .top, relatedBy: .equal,
                                                   toItem: self.topLayoutGuide, attribute: .bottom, multiplier: 1,
                                                   constant: 0))
        self.progressIndicator.autoPinEdge(toSuperviewEdge: .leading)
        self.progressIndicator.autoPinEdge(toSuperviewEdge: .trailing)
        self.progressIndicator.progressTintColor = UIColor.darkGreen
        self.progressIndicator.isHidden = true

        self.content.allowsLinkPreview = true
        self.content.navigationDelegate = self
        self.content.uiDelegate = self
        self.content.isOpaque = false
        self.content.scrollView.scrollIndicatorInsets.bottom = 0

        self.themeRepository.addSubscriber(self)
    }
}

extension HTMLViewController: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        let navigationType = navigationAction.navigationType
        guard let url = request.url, navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }
        if self.delegate?.openURL(url: url) == true {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.progressIndicator.isHidden = self.htmlString != nil
    }

    public func webView(_ webView: WKWebView,
                        previewingViewControllerForElement elementInfo: WKPreviewElementInfo,
                        defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
        guard let url = elementInfo.linkURL else { return nil }
        return self.delegate?.peekURL(url: url)
    }

    public func webView(_ webView: WKWebView,
                        commitPreviewingViewController previewingViewController: UIViewController) {
        self.delegate?.commitViewController(viewController: previewingViewController)
    }
}

extension HTMLViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        if let htmlString = self.htmlString {
            self.configure(html: htmlString)
        }

        self.content.backgroundColor = themeRepository.backgroundColor
        self.content.scrollView.backgroundColor = themeRepository.backgroundColor
        self.content.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.view.backgroundColor = themeRepository.backgroundColor
        self.progressIndicator.trackTintColor = themeRepository.backgroundColor
    }
}
