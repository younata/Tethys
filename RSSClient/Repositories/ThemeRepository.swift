import UIKit
import Ra

public protocol ThemeRepositorySubscriber: NSObjectProtocol {
    func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository)
}

public class ThemeRepository: NSObject, Injectable {
    public private(set) var backgroundColor: UIColor {
        get {
            let color = self.colorForKey("backgroundColor")
            return color ?? UIColor.whiteColor()
        }
        set {
            self.setColor(newValue, forKey: "backgroundColor")
        }
    }

    public private(set) var textColor: UIColor {
        get {
            let color = self.colorForKey("textColor")
            return color ?? UIColor.blackColor()
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
            self.privateSetValue(newValue, forKey: "articleCss")
        }
    }

    public private(set) var syntaxHighlightFile: String {
        get {
            let fname = self.privateValueForKey("syntax") as? String
            return fname ?? "mac_classic"
        }
        set {
            self.privateSetValue(newValue, forKey: "syntax")
        }
    }

    public private(set) var barStyle: UIBarStyle {
        get {
            if let rawValue = self.privateValueForKey("barStyle") as? Int, barStyle = UIBarStyle(rawValue: rawValue) {
                return barStyle
            }
            return UIBarStyle.Default
        }
        set {
            self.privateSetValue(newValue.rawValue, forKey: "barStyle")
        }
    }

    public private(set) var statusBarStyle: UIStatusBarStyle {
        get {
            if let rawValue = self.privateValueForKey("statusBarStyle") as? Int,
                barStyle = UIStatusBarStyle(rawValue: rawValue) {
                    return barStyle
            }
            return UIStatusBarStyle.Default
        }
        set {
            self.privateSetValue(newValue.rawValue, forKey: "statusBarStyle")
        }
    }

    public private(set) var tintColor: UIColor {
        get {
            let color = self.colorForKey("tintColor")
            return color ?? UIColor.whiteColor()
        }
        set {
            self.setColor(newValue, forKey: "tintColor")
        }
    }

    public private(set) var scrollIndicatorStyle: UIScrollViewIndicatorStyle {
        get {
            if let rawValue = self.privateValueForKey("scrollIndicatorStyle") as? Int,
                scrollIndicatorStyle = UIScrollViewIndicatorStyle(rawValue: rawValue) {
                    return scrollIndicatorStyle
            }
            return .Black
        }
        set {
            self.privateSetValue(newValue.rawValue, forKey: "scrollIndicatorStyle")
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
        case Default = 0
        case Dark = 1

        public var description: String {
            switch self {
            case .Default:
                return NSLocalizedString("Default", comment: "")
            case .Dark:
                return NSLocalizedString("Dark", comment: "")
            }
        }

        public static func array() -> [Theme] {
            return [.Default, .Dark]
        }
    }

    public var theme: Theme {
        get {
            if let themeRawValue = self.privateValueForKey("theme") as? Int,
                let theme = Theme(rawValue: themeRawValue) {
                    return theme
            }
            return Theme.Default
        }
        set {
            self.privateSetValue(newValue.rawValue, forKey: "theme")

            switch newValue {
            case .Default:
                self.backgroundColor = UIColor.whiteColor()
                self.textColor = UIColor.blackColor()
                self.articleCSSFileName = "github2"
                self.tintColor = UIColor.whiteColor()
                self.syntaxHighlightFile = "mac_classic"
                self.barStyle = .Default
                self.statusBarStyle = .Default
                self.scrollIndicatorStyle = .Black
                self.errorColor = UIColor(red: 1, green: 0, blue: 0.2, alpha: 1)
            case .Dark:
                self.backgroundColor = UIColor.blackColor()
                self.textColor = UIColor.whiteColor()
                self.articleCSSFileName = "darkhub2"
                self.tintColor = UIColor.darkGrayColor()
                self.syntaxHighlightFile = "twilight"
                self.barStyle = .Black
                self.statusBarStyle = .LightContent
                self.scrollIndicatorStyle = .White
                self.errorColor = UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1)
            }


            for case let subscriber in self.subscribers.allObjects {
                if let themeSubscriber = subscriber as? ThemeRepositorySubscriber {
                    themeSubscriber.themeRepositoryDidChangeTheme(self)
                }
            }
        }
    }

    private let userDefaults: NSUserDefaults?

    private let subscribers = NSHashTable.weakObjectsHashTable()

    public func addSubscriber(subscriber: ThemeRepositorySubscriber) {
        self.subscribers.addObject(subscriber)
        subscriber.themeRepositoryDidChangeTheme(self)
    }

    private var values: [String: AnyObject] = [:]
    private func privateValueForKey(key: String) -> AnyObject? {
        if let _ = self.userDefaults {
            return self.userDefaults?.valueForKey(key)
        } else {
            return self.values[key]
        }
    }

    private func privateSetValue(value: AnyObject, forKey key: String) {
        if let _ = self.userDefaults {
            self.userDefaults?.setObject(value, forKey: key)
        } else {
            self.values[key] = value
        }
    }

    private func colorForKey(key: String) -> UIColor? {
        if let _ = self.userDefaults {
            guard let data = self.userDefaults?.objectForKey(key) as? NSData else {
                return nil
            }
            return NSKeyedUnarchiver.unarchiveObjectWithData(data) as? UIColor
        } else {
            return self.privateValueForKey(key) as? UIColor
        }
    }

    private func setColor(color: UIColor, forKey key: String) {
        if let _ = self.userDefaults {
            let data = NSKeyedArchiver.archivedDataWithRootObject(color)
            self.userDefaults?.setObject(data, forKey: key)
        } else {
            self.values[key] = color
        }
    }

    public init(userDefaults: NSUserDefaults?) {
        self.userDefaults = userDefaults
    }

    public required init(injector: Ra.Injector) {
        self.userDefaults = injector.create(NSUserDefaults) ??
            NSUserDefaults.standardUserDefaults()
    }

    deinit {
        self.userDefaults?.synchronize()
    }
}
