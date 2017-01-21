import Foundation
import Ra

public protocol SettingsRepositorySubscriber: NSObjectProtocol {
    func didChangeSetting(_: SettingsRepository)
}

public final class SettingsRepository: Injectable {
    private enum SettingsKeys: String {
        case showEstimatedReadingLabel
        case refreshControlLabel
    }

    public var showEstimatedReadingLabel: Bool = true {
        didSet {
            self.informSubscribers()
            self.userDefaults?.set(showEstimatedReadingLabel,
                                       forKey: SettingsKeys.showEstimatedReadingLabel.rawValue)
        }
    }

    public var refreshControl: RefreshControlStyle = .breakout {
        didSet {
            self.informSubscribers()
            self.userDefaults?.set(refreshControl.rawValue,
                                   forKey: SettingsKeys.refreshControlLabel.rawValue)
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

    private let subscribers = NSHashTable<AnyObject>.weakObjects()
    private let userDefaults: UserDefaults?

    public init(userDefaults: UserDefaults? = nil) {
        self.userDefaults = userDefaults

        if self.userDefaults?.object(forKey: SettingsKeys.showEstimatedReadingLabel.rawValue) != nil {
            self.showEstimatedReadingLabel =
                self.userDefaults?.bool(forKey: SettingsKeys.showEstimatedReadingLabel.rawValue) ?? true
        }
        if self.userDefaults?.object(forKey: SettingsKeys.refreshControlLabel.rawValue) != nil,
            let refreshControlInt = self.userDefaults?.integer(forKey: SettingsKeys.refreshControlLabel.rawValue) {
            self.refreshControl = RefreshControlStyle(rawValue: refreshControlInt) ?? RefreshControlStyle.breakout
        }
    }

    public required convenience init(injector: Injector) {
        self.init(userDefaults: injector.create(kind: UserDefaults.self))
    }

    deinit {
        self.userDefaults?.synchronize()
    }
}
