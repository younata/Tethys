import UIKit
import SafariServices
import PureLayout

public enum Documentation {
    case libraries
    case icons
}

public final class DocumentationViewController: UIViewController {
    public let documentation: Documentation
    private let themeRepository: ThemeRepository
    private let htmlViewController: HTMLViewController

    public init(documentation: Documentation,
                themeRepository: ThemeRepository,
                htmlViewController: HTMLViewController) {
        self.documentation = documentation
        self.themeRepository = themeRepository
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

        themeRepository.addSubscriber(self)
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
        let cssFileName = self.themeRepository.articleCSSFileName
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

extension DocumentationViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = convertToOptionalNSAttributedStringKeyDictionary([
            NSAttributedString.Key.foregroundColor.rawValue: themeRepository.textColor
        ])
        self.loadHTML()
    }
}

extension DocumentationViewController: HTMLViewControllerDelegate {
    public func openURL(url: URL) -> Bool {
        self.navigationController?.pushViewController(SFSafariViewController(url: url), animated: true)
        return true
    }

    public func peekURL(url: URL) -> UIViewController? {
        return SFSafariViewController(url: url)
    }

    public func commitViewController(viewController: UIViewController) {
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
