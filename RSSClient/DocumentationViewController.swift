import UIKit
import WebKit
import PureLayout
import Ra

public class DocumentationViewController: UIViewController, Injectable {
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
        let cssFileName = self.themeRepository.articleCSSFileName
        if let loc = bundle.URLForResource(cssFileName, withExtension: "css"),
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

    private let themeRepository: ThemeRepository

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(themeRepository: injector.create(ThemeRepository)!)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.content)
        self.content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.themeRepository.addSubscriber(self)
    }
}

extension DocumentationViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.backgroundColor
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.content.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }
}
