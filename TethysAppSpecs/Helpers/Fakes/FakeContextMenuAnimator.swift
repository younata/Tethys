import UIKit
import Nimble

class FakeContextMenuAnimator: NSObject, UIContextMenuInteractionCommitAnimating {
    var preferredCommitStyle: UIContextMenuInteractionCommitStyle
    var previewViewController: UIViewController?

    init(commitStyle: UIContextMenuInteractionCommitStyle, viewController: UIViewController?) {
        self.preferredCommitStyle = commitStyle
        self.previewViewController = viewController
        super.init()
    }

    private(set) var addAnimationsCalls: [() -> Void] = []
    func addAnimations(_ animations: @escaping () -> Void) {
        self.addAnimationsCalls.append(animations)
    }

    private(set) var addCompletionCalls: [() -> Void] = []
    func addCompletion(_ completion: @escaping () -> Void) {
        self.addCompletionCalls.append(completion)
    }
}
