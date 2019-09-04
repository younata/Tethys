import UIKit
import CBGPromise
@testable import Tethys

final class FakeMessenger: Messenger {
    private(set) var warningCalls: [(title: String, message: String)] = []
    func warning(title: String, message: String) {
        self.warningCalls.append((title, message))
    }
}