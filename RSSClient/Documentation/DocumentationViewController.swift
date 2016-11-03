import UIKit
import SafariServices
import Ra
import PureLayout

public final class DocumentationViewController: UIViewController, Injectable {
    public private(set) var documentation: Documentation?
    fileprivate let documentationUseCase: DocumentationUseCase
    fileprivate let htmlViewController: HTMLViewController

    public init(documentationUseCase: DocumentationUseCase,
                themeRepository: ThemeRepository,
                htmlViewController: HTMLViewController) {
        self.documentationUseCase = documentationUseCase
        self.htmlViewController = htmlViewController

        super.init(nibName: nil, bundle: nil)

        themeRepository.addSubscriber(self)
        htmlViewController.delegate = self
        self.addChildViewController(htmlViewController)
    }

    public required convenience init(injector: Injector) {
        self.init(
            documentationUseCase: injector.create(kind: DocumentationUseCase.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            htmlViewController: injector.create(kind: HTMLViewController.self)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(documentation: Documentation) {
        self.documentation = documentation
        self.title = self.documentationUseCase.title(documentation: documentation)
        self.htmlViewController.configure(html: self.documentationUseCase.html(documentation: documentation))

        self.view.addSubview(self.htmlViewController.view)
        self.htmlViewController.view.autoPinEdgesToSuperviewEdges()
    }
}

extension DocumentationViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]
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
