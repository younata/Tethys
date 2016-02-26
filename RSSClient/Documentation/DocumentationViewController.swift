import UIKit
import WebKit
import PureLayout
import Ra

public class DocumentationViewController: UIViewController, Injectable {
    public private(set) var document: Document = .QueryFeed
    public func configure(document: Document) {
        self.document = document

        self.title = document.title
        self.content.loadHTMLString(self.documentationUseCase.htmlForDocument(document) ?? "", baseURL: nil)
    }

    private let content: WKWebView = WKWebView(forAutoLayout: ())

    private let themeRepository: ThemeRepository
    private let documentationUseCase: DocumentationUseCase

    public init(themeRepository: ThemeRepository, documentationUseCase: DocumentationUseCase) {
        self.themeRepository = themeRepository
        self.documentationUseCase = documentationUseCase
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            documentationUseCase: injector.create(DocumentationUseCase)!
        )
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
