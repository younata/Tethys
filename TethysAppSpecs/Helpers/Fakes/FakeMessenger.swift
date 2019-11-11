import UIKit
import CBGPromise
@testable import Tethys

struct MessageCall: Equatable {
    let title: String
    let message: String
}

final class FakeMessenger: Messenger {
    private(set) var warningCalls: [MessageCall] = []
    func warning(title: String, message: String) {
        self.warningCalls.append(MessageCall(title: title, message: message))
    }

    private(set) var errorCalls: [MessageCall] = []
    func error(title: String, message: String) {
        self.errorCalls.append(MessageCall(title: title, message: message))
    }
}
