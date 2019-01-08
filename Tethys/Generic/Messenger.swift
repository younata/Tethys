import UIKit
import CBGPromise
import SwiftMessages

public protocol Messenger {
    func warning(title: String, message: String)
}

struct SwiftMessenger: Messenger {
    func warning(title: String, message: String) {
        let view = MessageView.viewFromNib(layout: .tabView)
        view.configureTheme(.warning)
        view.configureDropShadow()
        view.configureContent(title: title, body: message)
        view.button?.isHidden = true
        SwiftMessages.show(view: view)
    }
}
