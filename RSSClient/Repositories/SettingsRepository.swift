import Foundation
import Ra

public protocol SettingsRepositorySubscriber: NSObjectProtocol {
    func didChangeSetting(_: SettingsRepository)
}

public final class SettingsRepository: Injectable {
    private enum SettingsKeys: String {
        case ShowEstimatedReadingLabel = "showEstimatedReadingLabel"
    }

    public var showEstimatedReadingLabel: Bool = true {
        didSet {
            self.informSubscribers()
            self.userDefaults?.set(showEstimatedReadingLabel,
                                       forKey: SettingsKeys.ShowEstimatedReadingLabel.rawValue)
        }
    }

    public func addSubscriber(_ subscriber: SettingsRepositorySubscriber) {
        subscriber.didChangeSetting(self)
        self.subscribers.add(subscriber)
    }

    private func informSubscribers() {
        for object in self.subscribers.allObjects {
            if let subscriber = object as? SettingsRepositorySubscriber {
                subscriber.didChangeSetting(self)
            }
        }
    }

    private let subscribers = NSHashTable.weakObjects()
    private let userDefaults: UserDefaults?

    public init(userDefaults: UserDefaults? = nil) {
        self.userDefaults = userDefaults

        if self.userDefaults?.object(forKey: SettingsKeys.ShowEstimatedReadingLabel.rawValue) != nil {
            self.showEstimatedReadingLabel =
                self.userDefaults?.bool(forKey: SettingsKeys.ShowEstimatedReadingLabel.rawValue) ?? true
        }
    }

    public required convenience init(injector: Injector) {
        self.init(userDefaults: injector.create(UserDefaults))
    }

    deinit {
        self.userDefaults?.synchronize()
    }
}
