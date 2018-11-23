import UIKit

public protocol ThemeRepositorySubscriber: NSObjectProtocol {
    func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository)
}

public final class ThemeRepository: NSObject {
    public var backgroundColor: UIColor { return self.theme.backgroundColor }
    public var textColor: UIColor { return self.theme.textColor }
    public var articleCSSFileName: String { return self.theme.articleCSSFileName }
    public var barStyle: UIBarStyle { return self.theme.barStyle }
    public var statusBarStyle: UIStatusBarStyle { return self.theme.statusBarStyle }
    public var tintColor: UIColor { return self.theme.tintColor }
    public var scrollIndicatorStyle: UIScrollViewIndicatorStyle { return self.theme.scrollIndicatorStyle }
    public var spinnerStyle: UIActivityIndicatorViewStyle { return self.theme.spinnerStyle }
    public var errorColor: UIColor { return self.theme.errorColor }

    public enum Theme: Int, CustomStringConvertible {
        case light = 0
        case dark = 1

        public var description: String {
            switch self {
            case .light:
                return NSLocalizedString("Theme_Light", comment: "")
            case .dark:
                return NSLocalizedString("Theme_Dark", comment: "")
            }
        }

        public static func array() -> [Theme] {
            return [.light, .dark]
        }

        public var backgroundColor: UIColor {
            switch self {
            case .light:
                return UIColor.white
            case .dark:
                return UIColor.black
            }
        }

        public var textColor: UIColor {
            switch self {
            case .light:
                return UIColor.black
            case .dark:
                return UIColor(white: 0.85, alpha: 1)
            }
        }

        public var articleCSSFileName: String {
            switch self {
            case .light:
                return "github2"
            case .dark:
                return "darkhub2"
            }
        }

        public var tintColor: UIColor {
            switch self {
            case .light:
                return UIColor.white
            case .dark:
                return UIColor.darkGray
            }
        }

        public var barStyle: UIBarStyle {
            switch self {
            case .light:
                return .default
            case .dark:
                return .black
            }
        }

        public var statusBarStyle: UIStatusBarStyle {
            switch self {
            case .light:
                return .default
            case .dark:
                return .lightContent
            }
        }

        public var scrollIndicatorStyle: UIScrollViewIndicatorStyle {
            switch self {
            case .light:
                return .black
            case .dark:
                return .white
            }
        }

        public var spinnerStyle: UIActivityIndicatorViewStyle {
            switch self {
            case .light:
                return .gray
            case .dark:
                return .white
            }
        }

        public var errorColor: UIColor {
            switch self {
            case .light:
                return UIColor(red: 1, green: 0, blue: 0.2, alpha: 1)
            case .dark:
                return UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1)
            }
        }

    }

    public var theme: Theme {
        get {
            if let themeRawValue = self.privateValueForKey("theme") as? Int,
                let theme = Theme(rawValue: themeRawValue) {
                    return theme
            }
            return Theme.dark
        }
        set {
            self.privateSetValue(newValue.rawValue as AnyObject, forKey: "theme")

            for case let subscriber in self.subscribers.allObjects {
                if let themeSubscriber = subscriber as? ThemeRepositorySubscriber {
                    themeSubscriber.themeRepositoryDidChangeTheme(self)
                }
            }
        }
    }

    private let userDefaults: UserDefaults?

    private let subscribers = NSHashTable<AnyObject>.weakObjects()

    public func addSubscriber(_ subscriber: ThemeRepositorySubscriber) {
        self.subscribers.add(subscriber)
        subscriber.themeRepositoryDidChangeTheme(self)
    }

    private var values: [String: AnyObject] = [:]
    private func privateValueForKey(_ key: String) -> Any? {
        if self.userDefaults != nil {
            return self.userDefaults?.value(forKey: key)
        } else {
            return self.values[key]
        }
    }

    private func privateSetValue(_ value: AnyObject, forKey key: String) {
        if self.userDefaults != nil {
            self.userDefaults?.set(value, forKey: key)
        } else {
            self.values[key] = value
        }
    }

    public init(userDefaults: UserDefaults?) {
        self.userDefaults = userDefaults
    }

    deinit {
        self.userDefaults?.synchronize()
    }
}
