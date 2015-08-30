import UIKit
import Ra

public protocol ThemeRepositorySubscriber: NSObjectProtocol {
    func didChangeTheme()
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
            let fname = self.userDefaults.stringForKey("articleCss")
            return fname ?? "github2"
        }
        set {
            self.userDefaults.setObject(newValue, forKey: "articleCss")
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

    public enum Theme: Int {
        case Default = 0
        case Dark = 1
    }

    public var theme: Theme = .Default {
        didSet {
            switch theme {
            case .Default:
                self.backgroundColor = UIColor.whiteColor()
                self.textColor = UIColor.blackColor()
                self.articleCSSFileName = "github2"
                self.tintColor = UIColor.whiteColor()
            case .Dark:
                self.backgroundColor = UIColor.blackColor()
                self.textColor = UIColor.whiteColor()
                self.articleCSSFileName = "darkhub2"
                self.tintColor = UIColor.darkGrayColor()
            }

            for case let subscriber in self.subscribers.allObjects {
                if let themeSubscriber = subscriber as? ThemeRepositorySubscriber {
                    themeSubscriber.didChangeTheme()
                }
            }
        }
    }

    private let userDefaults: NSUserDefaults

    private let subscribers = NSHashTable.weakObjectsHashTable()

    public required init(injector: Ra.Injector) {
        self.userDefaults = injector.create(NSUserDefaults.self) as? NSUserDefaults ?? NSUserDefaults.standardUserDefaults()
    }

    public func addSubscriber(subscriber: ThemeRepositorySubscriber) {
        self.subscribers.addObject(subscriber)
        subscriber.didChangeTheme()
    }

    private func colorForKey(key: String) -> UIColor? {
        guard let data = self.userDefaults.objectForKey(key) as? NSData else {
            return nil
        }
        return NSKeyedUnarchiver.unarchiveObjectWithData(data) as? UIColor
    }

    private func setColor(color: UIColor, forKey key: String) {
        let data = NSKeyedArchiver.archivedDataWithRootObject(color)
        self.userDefaults.setObject(data, forKey: key)
    }
}