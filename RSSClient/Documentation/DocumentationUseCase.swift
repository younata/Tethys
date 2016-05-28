import Foundation
import Ra

public enum Document: String {
    case QueryFeed = "queryFeedDocumentation"

    public var title: String {
        switch self {
        case .QueryFeed:
            return NSLocalizedString("DocumentTitle_QueryFeeds", comment: "")
        }
    }
}

public protocol DocumentationUseCase {
    func htmlForDocument(document: Document) -> String?
}

public struct DefaultDocumentationUseCase: DocumentationUseCase, Injectable {
    private let bundle: NSBundle
    private let themeRepository: ThemeRepository

    public init(bundle: NSBundle, themeRepository: ThemeRepository) {
        self.bundle = bundle
        self.themeRepository = themeRepository
    }

    public init(injector: Injector) {
        self.init(
            bundle: injector.create(NSBundle.self)!,
            themeRepository: injector.create(ThemeRepository.self)!
        )
    }

    public func htmlForDocument(document: Document) -> String? {
        if let documentUrl = self.bundle.URLForResource(document.rawValue, withExtension: "html"),
            documentString = try? String(contentsOfURL: documentUrl, encoding: NSUTF8StringEncoding) {
                return self.cssString() + documentString + self.prismJS() + "</body></html>"
        }
        return nil
    }

    private func cssString() -> String {
        let cssFileName = self.themeRepository.articleCSSFileName
        if let loc = self.bundle.URLForResource(cssFileName, withExtension: "css"),
            cssString = try? String(contentsOfURL: loc, encoding: NSUTF8StringEncoding) {
                return "<html><head><style type=\"text/css\">\(cssString)</style></head><body>"
        }
        return "<html><body>"
    }

    private func prismJS() -> String {
        if let loc = self.bundle.URLForResource("prism.js", withExtension: "html"),
            prismJS = try? String(contentsOfURL: loc, encoding: NSUTF8StringEncoding) {
                return prismJS
        }
        return ""
    }
}
