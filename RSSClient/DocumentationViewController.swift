import UIKit
import WebKit
import PureLayout

public class DocumentationViewController: UIViewController {
    public enum Document: String {
        case QueryFeed = "queryFeedDocumentation"

        private var description: String {
            switch self {
            case .QueryFeed:
                return NSLocalizedString("DocumentationViewController_DocumentTitle_QueryFeeds", comment: "")
            }
        }
    }

    public private(set) var document: Document = .QueryFeed
    public func configure(document: Document) {
        self.document = document

        self.navigationItem.title = document.description
        let bundle = NSBundle(forClass: self.classForCoder)
        if let documentUrl = bundle.URLForResource(document.rawValue, withExtension: "html"),
            let documentNSString = try? NSString(contentsOfURL: documentUrl, encoding: NSUTF8StringEncoding) {
                let documentString = String(documentNSString)

                let contentString = self.cssString() + documentString + self.prismJS() + "</body></html>"

                self.content.loadHTMLString(contentString, baseURL: nil)
        }
    }

    private func cssString() -> String {
        let bundle = NSBundle(forClass: self.classForCoder)
        if let cssFileName = self.themeRepository?.articleCSSFileName,
            let loc = bundle.URLForResource(cssFileName, withExtension: "css"),
            let cssNSString = try? NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding) {
                return "<html><head><style type=\"text/css\">\(String(cssNSString))</style></head><body>"
        }
        return "<html><body>"
    }

    private func prismJS() -> String {
        let bundle = NSBundle(forClass: self.classForCoder)
        if let loc = bundle.URLForResource("prism.js", withExtension: "html"),
            let prismJS = try? NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding) as String {
                return prismJS
        }
        return ""
    }

    private let content: WKWebView = WKWebView(forAutoLayout: ())

    private lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository)
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.content)
        self.content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.themeRepository?.addSubscriber(self)
    }
}

extension DocumentationViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.view.backgroundColor = self.themeRepository?.backgroundColor
        if let themeRepository = self.themeRepository {
            self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
            self.content.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
        }
    }
}
