import UIKit
import Ra

public protocol ThemeRepositorySubscriber: NSObjectProtocol {
    func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository)
}

public final class ThemeRepository: NSObject, Injectable {
    public private(set) var backgroundColor: UIColor {
        get {
            let color = self.colorForKey("backgroundColor")
            return color ?? UIColor.white
        }
        set {
            self.setColor(newValue, forKey: "backgroundColor")
        }
    }

    public private(set) var textColor: UIColor {
        get {
            let color = self.colorForKey("textColor")
            return color ?? UIColor.black
        }
        set {
            self.setColor(newValue, forKey: "textColor")
        }
    }

    public private(set) var articleCSSFileName: String {
        get {
            let fname = self.privateValueForKey("articleCss") as? String
            return fname ?? "github2"
        }
        set {
            self.privateSetValue(newValue as AnyObject, forKey: "articleCss")
        }
    }

    public private(set) var syntaxHighlightFile: String {
        get {
            let fname = self.privateValueForKey("syntax") as? String
            return fname ?? "mac_classic"
        }
        set {
            self.privateSetValue(newValue as AnyObject, forKey: "syntax")
        }
    }

    public private(set) var barStyle: UIBarStyle {
        get {
            if let rawValue = self.privateValueForKey("barStyle") as? Int, let barStyle = UIBarStyle(rawValue: rawValue) {
                return barStyle
            }
            return UIBarStyle.default
        }
        set {
            self.privateSetValue(newValue.rawValue as AnyObject, forKey: "barStyle")
        }
    }

    public private(set) var statusBarStyle: UIStatusBarStyle {
        get {
            if let rawValue = self.privateValueForKey("statusBarStyle") as? Int,
                let barStyle = UIStatusBarStyle(rawValue: rawValue) {
                    return barStyle
            }
            return UIStatusBarStyle.default
        }
        set {
            self.privateSetValue(newValue.rawValue as AnyObject, forKey: "statusBarStyle")
        }
    }

    public private(set) var tintColor: UIColor {
        get {
            let color = self.colorForKey("tintColor")
            return color ?? UIColor.white
        }
        set {
            self.setColor(newValue, forKey: "tintColor")
        }
    }

    public private(set) var scrollIndicatorStyle: UIScrollViewIndicatorStyle {
        get {
            if let rawValue = self.privateValueForKey("scrollIndicatorStyle") as? Int,
                let scrollIndicatorStyle = UIScrollViewIndicatorStyle(rawValue: rawValue) {
                    return scrollIndicatorStyle
            }
            return .black
        }
        set {
            self.privateSetValue(newValue.rawValue as AnyObject, forKey: "scrollIndicatorStyle")
        }
    }

    public private(set) var spinnerStyle: UIActivityIndicatorViewStyle {
        get {
            if let rawValue = self.privateValueForKey("spinnerStyle") as? Int,
                let spinnerStyle = UIActivityIndicatorViewStyle(rawValue: rawValue) {
                return spinnerStyle
            }
            return .gray
        }
        set {
            self.privateSetValue(newValue.rawValue as AnyObject, forKey: "spinnerStyle")
        }
    }

    public private(set) var errorColor: UIColor {
        get {
            let color = self.colorForKey("errorColor")
            return color ?? UIColor(red: 1, green: 0, blue: 0.2, alpha: 1)
        }
        set {
            self.setColor(newValue, forKey: "errorColor")
        }
    }

    public enum Theme: Int, CustomStringConvertible {
        case `default` = 0
        case dark = 1

        public var description: String {
            switch self {
            case .default:
                return NSLocalizedString("Default", comment: "")
            case .dark:
                return NSLocalizedString("Dark", comment: "")
            }
        }

        public static func array() -> [Theme] {
            return [.default, .dark]
        }
    }

    public var theme: Theme {
        get {
            if let themeRawValue = self.privateValueForKey("theme") as? Int,
                let theme = Theme(rawValue: themeRawValue) {
                    return theme
            }
            return Theme.default
        }
        set {
            self.privateSetValue(newValue.rawValue as AnyObject, forKey: "theme")

            switch newValue {
            case .default:
                self.backgroundColor = UIColor.white
                self.textColor = UIColor.black
                self.articleCSSFileName = "github2"
                self.tintColor = UIColor.white
                self.syntaxHighlightFile = "mac_classic"
                self.barStyle = .default
                self.statusBarStyle = .default
                self.scrollIndicatorStyle = .black
                self.spinnerStyle = .gray
                self.errorColor = UIColor(red: 1, green: 0, blue: 0.2, alpha: 1)
            case .dark:
                self.backgroundColor = UIColor.black
                self.textColor = UIColor.white
                self.articleCSSFileName = "darkhub2"
                self.tintColor = UIColor.darkGray
                self.syntaxHighlightFile = "twilight"
                self.barStyle = .black
                self.statusBarStyle = .lightContent
                self.scrollIndicatorStyle = .white
                self.spinnerStyle = .white
                self.errorColor = UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1)
            }


            for case let subscriber in self.subscribers.allObjects {
                if let themeSubscriber = subscriber as? ThemeRepositorySubscriber {
                    themeSubscriber.themeRepositoryDidChangeTheme(self)
                }
            }
        }
    }

    private let userDefaults: UserDefaults?

    private let subscribers = NSHashTable.weakObjects()

    public func addSubscriber(_ subscriber: ThemeRepositorySubscriber) {
        self.subscribers.add(subscriber)
        subscriber.themeRepositoryDidChangeTheme(self)
    }

    private var values: [String: AnyObject] = [:]
    private func privateValueForKey(_ key: String) -> AnyObject? {
        if let _ = self.userDefaults {
            return self.userDefaults?.value(forKey: key)
        } else {
            return self.values[key]
        }
    }

    private func privateSetValue(_ value: AnyObject, forKey key: String) {
        if let _ = self.userDefaults {
            self.userDefaults?.set(value, forKey: key)
        } else {
            self.values[key] = value
        }
    }

    private func colorForKey(_ key: String) -> UIColor? {
        if let _ = self.userDefaults {
            guard let data = self.userDefaults?.object(forKey: key) as? Data else {
                return nil
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? UIColor
        } else {
            return self.privateValueForKey(key) as? UIColor
        }
    }

    private func setColor(_ color: UIColor, forKey key: String) {
        if let _ = self.userDefaults {
            let data = NSKeyedArchiver.archivedData(withRootObject: color)
            self.userDefaults?.set(data, forKey: key)
        } else {
            self.values[key] = color
        }
    }

    public init(userDefaults: UserDefaults?) {
        self.userDefaults = userDefaults
    }

    public required init(injector: Ra.Injector) {
        self.userDefaults = injector.create(UserDefaults) ??
            UserDefaults.standardUserDefaults()
    }

    deinit {
        self.userDefaults?.synchronize()
    }
}
