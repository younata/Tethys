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

    public init() {
        super.init(nibName: nil, bundle: nil)

        self.content.isOpaque = false
        self.observer = self.content.observe(\.estimatedProgress, options: [.new]) { _, _ in
            self.progressIndicator.progress = Float(self.content.estimatedProgress)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.content)
        self.view.addSubview(self.progressIndicator)

        self.content.autoPinEdgesToSuperviewEdges()

        self.view.addConstraint(NSLayoutConstraint(item: self.progressIndicator, attribute: .top, relatedBy: .equal,
                                                   toItem: self.view.safeAreaLayoutGuide, attribute: .bottom,
                                                   multiplier: 1, constant: 0))
        self.progressIndicator.autoPinEdge(toSuperviewEdge: .leading)
        self.progressIndicator.autoPinEdge(toSuperviewEdge: .trailing)
        self.progressIndicator.isHidden = true

        self.content.allowsLinkPreview = true
        self.content.navigationDelegate = self
        self.content.uiDelegate = self
        self.content.isOpaque = false
        self.content.scrollView.verticalScrollIndicatorInsets.bottom = 0
        self.content.scrollView.horizontalScrollIndicatorInsets.bottom = 0

        self.applyTheme()
    }

    private func applyTheme() {
        self.content.backgroundColor = Theme.backgroundColor
        self.content.scrollView.backgroundColor = Theme.backgroundColor

        self.view.backgroundColor = Theme.backgroundColor
        self.progressIndicator.trackTintColor = Theme.progressTrackColor
        self.progressIndicator.progressTintColor = Theme.progressTintColor
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
