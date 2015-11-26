import UIKit

public protocol QuickActionRepository {
    @available (iOS 9, *)
    var quickActions: [UIApplicationShortcutItem] { get set }
}

extension UIApplication: QuickActionRepository {
    @available(iOS 9.0, *)
    public var quickActions: [UIApplicationShortcutItem] {
        get {
            return self.shortcutItems ?? []
        }
        set {
            self.shortcutItems = newValue
        }
    }
}
