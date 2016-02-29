import Foundation
import Ra

public protocol SettingsRepositorySubscriber: NSObjectProtocol {
    func didChangeSetting(_: SettingsRepository)
}

public class SettingsRepository: Injectable {
    private enum SettingsKeys: String {
        case QueryFeedsEnabled = "queryFeedsEnabled"
    }

    public var queryFeedsEnabled: Bool = false {
        didSet {
            self.informSubscribers()
            self.userDefaults?.setBool(queryFeedsEnabled, forKey: SettingsKeys.QueryFeedsEnabled.rawValue)
        }
    }

    public func addSubscriber(subscriber: SettingsRepositorySubscriber) {
        subscriber.didChangeSetting(self)
        self.subscribers.addObject(subscriber)
    }

    private func informSubscribers() {
        for object in self.subscribers.allObjects {
            if let subscriber = object as? SettingsRepositorySubscriber {
                subscriber.didChangeSetting(self)
            }
        }
    }

    private let subscribers = NSHashTable.weakObjectsHashTable()
    private let userDefaults: NSUserDefaults?

    public init(userDefaults: NSUserDefaults? = nil) {
        self.userDefaults = userDefaults

        self.queryFeedsEnabled = self.userDefaults?.boolForKey(SettingsKeys.QueryFeedsEnabled.rawValue) ?? false
    }

    public required convenience init(injector: Injector) {
        self.init(userDefaults: injector.create(NSUserDefaults))
    }

    deinit {
        self.userDefaults?.synchronize()
    }
}
