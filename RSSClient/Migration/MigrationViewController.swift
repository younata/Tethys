import UIKit
import PureLayout
import Ra

public final class MigrationViewController: UIViewController, Injectable {
    public let label: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.text = NSLocalizedString("MigrationViewController_Message", comment: "")
        label.textAlignment = .Center
        return label
    }()

    public let progressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .Default)
        bar.translatesAutoresizingMaskIntoConstraints = true
        bar.progressTintColor = UIColor.darkGreenColor()
        return bar
    }()

    private let activityIndicator = UIActivityIndicatorView(forAutoLayout: ())

    public init(migrationUseCase: MigrationUseCase, themeRepository: ThemeRepository) {
        super.init(nibName: nil, bundle: nil)

        migrationUseCase.addSubscriber(self)
        themeRepository.addSubscriber(self)
    }

    public required convenience init(injector: Injector) {
        self.init(
            migrationUseCase: injector.create(MigrationUseCase)!,
            themeRepository: injector.create(ThemeRepository)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.label)
        self.view.addSubview(self.progressBar)
        self.view.addSubview(self.activityIndicator)

        self.label.autoCenterInSuperview()
        self.label.autoPinEdgeToSuperviewEdge(.Leading, withInset: 20)
        self.label.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 20)

        self.progressBar.autoPinEdgeToSuperviewEdge(.Leading, withInset: 20)
        self.progressBar.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 20)
        self.progressBar.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.label)

        self.activityIndicator.autoAlignAxisToSuperviewAxis(.Vertical)
        self.activityIndicator.autoPinEdge(.Bottom, toEdge: .Top, ofView: self.label, withOffset: -8)

        self.activityIndicator.startAnimating()
    }
}

extension MigrationViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.backgroundColor
        self.label.textColor = themeRepository.textColor
        self.activityIndicator.color = themeRepository.textColor
    }
}

extension MigrationViewController: MigrationUseCaseSubscriber {
    public func migrationUseCase(migrationUseCase: MigrationUseCase, didUpdateProgress progress: Double) {
        self.progressBar.setProgress(Float(progress), animated: true)
    }

    public func migrationUseCaseDidFinish(migrationUseCase: MigrationUseCase) {}
}
