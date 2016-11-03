import Foundation
import Ra

public enum Documentation {
    case libraries
}

public protocol DocumentationUseCase {
    func html(documentation: Documentation) -> String
    func title(documentation: Documentation) -> String
}

public struct DefaultDocumentationUseCase: DocumentationUseCase, Injectable {
    public func html(documentation: Documentation) -> String {
        guard let url = Bundle.main.url(forResource: "libraries", withExtension: "html") else {
            return ""
        }
        return self.htmlFixes(content: (try? String(contentsOf: url)) ?? "")
    }

    public func title(documentation: Documentation) -> String {
        return NSLocalizedString("SettingsViewController_Credits_Libraries", comment: "")
    }

    private let themeRepository: ThemeRepository
    private let bundle: Bundle

    public init(themeRepository: ThemeRepository, bundle: Bundle) {
        self.themeRepository = themeRepository
        self.bundle = bundle
    }

    public init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            bundle: injector.create(kind: Bundle.self)!
        )
    }

    private func htmlFixes(content: String) -> String {
        let prefix: String
        let cssFileName = self.themeRepository.articleCSSFileName
        if let cssURL = self.bundle.url(forResource: cssFileName, withExtension: "css"),
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
