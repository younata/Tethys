import UIKit
import PureLayout
import Ra
import rNewsKit

public final class MigrationViewController: UIViewController, Injectable {
    public let label: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.text = NSLocalizedString("MigrationViewController_Message", comment: "")
        label.textAlignment = .center
        return label
    }()

    public let progressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.translatesAutoresizingMaskIntoConstraints = true
        bar.progressTintColor = UIColor.darkGreen()
        return bar
    }()

    fileprivate let activityIndicator = UIActivityIndicatorView(forAutoLayout: ())
    fileprivate let mainQueue: OperationQueue

    public init(migrationUseCase: MigrationUseCase, themeRepository: ThemeRepository, mainQueue: OperationQueue) {
        self.mainQueue = mainQueue

        super.init(nibName: nil, bundle: nil)

        migrationUseCase.addSubscriber(self)
        themeRepository.addSubscriber(self)
    }

    public required convenience init(injector: Injector) {
        self.init(
            migrationUseCase: injector.create(MigrationUseCase)!,
            themeRepository: injector.create(ThemeRepository)!,
            mainQueue: injector.create(kMainQueue) as! NSOperationQueue
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
        self.label.autoPinEdge(toSuperviewEdge: .leading, withInset: 20)
        self.label.autoPinEdge(toSuperviewEdge: .trailing, withInset: 20)

        self.progressBar.autoPinEdge(toSuperviewEdge: .leading, withInset: 20)
        self.progressBar.autoPinEdge(toSuperviewEdge: .trailing, withInset: 20)
        self.progressBar.autoPinEdge(.top, to: .bottom, of: self.label)

        self.activityIndicator.autoAlignAxis(toSuperviewAxis: .vertical)
        self.activityIndicator.autoPinEdge(.bottom, to: .top, of: self.label, withOffset: -8)

        self.activityIndicator.startAnimating()
    }
}

extension MigrationViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.backgroundColor
        self.label.textColor = themeRepository.textColor
        self.activityIndicator.color = themeRepository.textColor
    }
}

extension MigrationViewController: MigrationUseCaseSubscriber {
    public func migrationUseCase(_ migrationUseCase: MigrationUseCase, didUpdateProgress progress: Double) {
        self.mainQueue.addOperation {
            self.progressBar.setProgress(Float(progress), animated: true)
        }
    }

    public func migrationUseCaseDidFinish(_ migrationUseCase: MigrationUseCase) {}
}
