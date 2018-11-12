import Foundation

public enum Documentation {
    case libraries
    case icons
}

public protocol DocumentationUseCase {
    func html(documentation: Documentation) -> String
    func title(documentation: Documentation) -> String
}

public struct DefaultDocumentationUseCase: DocumentationUseCase {
    public func html(documentation: Documentation) -> String {
        let url: URL
        switch documentation {
        case .libraries:
            url = Bundle.main.url(forResource: "libraries", withExtension: "html")!
        case .icons:
            url = Bundle.main.url(forResource: "icons", withExtension: "html")!
        }
        return self.htmlFixes(content: (try? String(contentsOf: url)) ?? "")
    }

    public func title(documentation: Documentation) -> String {
        switch documentation {
        case .libraries:
            return NSLocalizedString("SettingsViewController_Credits_Libraries", comment: "")
        case .icons:
            return NSLocalizedString("SettingsViewController_Credits_Icons", comment: "")
        }
    }

    private let themeRepository: ThemeRepository

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository
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
