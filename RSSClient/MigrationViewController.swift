import UIKit
import PureLayout

public final class MigrationViewController: UIViewController {
    public let activityIndicator = ActivityIndicator(forAutoLayout: ())
    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.activityIndicator)
        self.activityIndicator.autoPinEdgesToSuperviewEdges()

        self.activityIndicator.configureWithMessage(NSLocalizedString("MigrationViewController_Message", comment: ""))
    }
}
