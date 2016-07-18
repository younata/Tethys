import UIKit

public class LoginViewController: UIViewController {
    private let stackView: UIStackView = {
        let stackView = UIStackView(forAutoLayout: ())
        stackView.axis = .Vertical
        stackView.distribution = .EqualCentering
        stackView.alignment = .Center
        return stackView
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.stackView)
    }
}
