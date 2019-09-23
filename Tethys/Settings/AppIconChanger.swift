import UIKit

public protocol AppIconChanger: class {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func setAlternateIconName(_ alternateIconName: String?, completionHandler: ((Error?) -> Void)?)
}

public enum AppIcon: Int, Identifiable {
    case primary = 0
    case black = 1

    public init?(name: String?) {
        switch name {
        case nil:
            self = .primary
        case "AppIcon-Black":
            self = .black
        default:
            return nil
        }
    }

    public var id: ObjectIdentifier {
        return ObjectIdentifier(self.rawValue as NSNumber)
    }

    public var internalName: String? {
        switch self {
        case .primary: return nil
        case .black: return "AppIcon-Black"
        }
    }

    public var localizedName: String {
        switch self {
        case .primary: return NSLocalizedString("SettingsViewController_AlternateIcons_Primary", comment: "")
        case .black: return NSLocalizedString("SettingsViewController_AlternateIcons_Black", comment: "")
        }
    }

    public var imageName: String {
        switch self {
        case .primary: return "DefaultAppIcon"
        case .black: return "BlackAppIcon"
        }
    }

    public var accessibilityId: String {
        switch self {
        case .primary: return "Default"
        case .black: return "Black"
        }
    }

    public static var all: [AppIcon] {
        return [.primary, .black]
    }
}

extension UIApplication: AppIconChanger {}
