import UIKit
import SafariServices
import PureLayout

public enum Documentation {
    case libraries
    case icons
}

public final class DocumentationViewController: UIViewController {
    public let documentation: Documentation
    private let htmlViewController: HTMLViewController

    public init(documentation: Documentation,
                htmlViewController: HTMLViewController) {
        self.documentation = documentation
        self.htmlViewController = htmlViewController

        super.init(nibName: nil, bundle: nil)

        htmlViewController.delegate = self
        self.addChild(htmlViewController)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        self.view.addSubview(self.htmlViewController.view)
        self.htmlViewController.view.autoPinEdgesToSuperviewEdges()

        switch self.documentation {
        case .libraries:
            self.title = NSLocalizedString("SettingsViewController_Credits_Libraries", comment: "")
        case .icons:
            self.title = NSLocalizedString("SettingsViewController_Credits_Icons", comment: "")
        }

        self.loadHTML()
    }

    fileprivate func loadHTML() {
        let url: URL
        switch self.documentation {
        case .libraries:
            url = Bundle.main.url(forResource: "libraries", withExtension: "html")!
        case .icons:
            url = Bundle.main.url(forResource: "icons", withExtension: "html")!
        }
        self.htmlViewController.configure(html: self.htmlFixes(content: (try? String(contentsOf: url)) ?? ""))
    }

    private func htmlFixes(content: String) -> String {
        let prefix: String
        let cssFileName = Theme.articleCSSFileName
        if let cssURL = Bundle.main.url(forResource: cssFileName, withExtension: "css"),
            let css = try? String(contentsOf: cssURL) {
            prefix = "<html><head>" +
                "<style type=\"text/css\">\(css)</style>" +
                "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
            "</head><body>"
        } else {
            prefix = "<html><body>"
        }

        let postfix = "</body></html>"

        return prefix + content + postfix
    }
}

extension DocumentationViewController: HTMLViewControllerDelegate {
    public func openURL(url: URL) -> Bool {
        self.navigationController?.pushViewController(SFSafariViewController(url: url), animated: true)
        return true
    }

    public func peekURL(url: URL) -> UIViewController? {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = Theme.highlightColor
        return vc
    }

    public func commitViewController(viewController: UIViewController) {
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}
