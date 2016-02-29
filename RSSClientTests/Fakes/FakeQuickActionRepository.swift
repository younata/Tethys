import rNews

class FakeQuickActionRepository: QuickActionRepository {
    var _quickActions = [NSObject]()

    @available (iOS 9, *)
    var quickActions: [UIApplicationShortcutItem] {
        get {
            return (self._quickActions as? [UIApplicationShortcutItem]) ?? []
        }
        set {
            self._quickActions = newValue
        }
    }
}