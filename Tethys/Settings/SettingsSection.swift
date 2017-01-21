import Foundation
import TethysKit

extension Account: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pasiphae:
            return NSLocalizedString("SettingsViewController_Accounts_Pasiphae", comment: "")
        }
    }
}

enum SettingsSection: CustomStringConvertible {
    case theme
    case refresh
    case quickActions
    case accounts
    case other
    case credits

    init?(rawValue: Int, traits: UITraitCollection) {
        if rawValue == 0 {
            self = .theme
            return
        } else if rawValue == 1 {
            self = .refresh
            return
        } else {
            let offset: Int
            switch traits.forceTouchCapability {
            case .available:
                offset = 0
            case .unavailable, .unknown:
                offset = 1
            }
            switch rawValue + offset {
            case 2:
                self = .quickActions
//            case 3:
//                self = .accounts
            case 3:
                self = .other
            case 4:
                self = .credits
            default:
                return nil
            }
        }
    }

    static func numberOfSettings(_ traits: UITraitCollection) -> Int {
        if traits.forceTouchCapability == .available {
            return 5
        }
        return 4
    }

    var rawValue: Int {
        switch self {
        case .theme: return 0
        case .refresh: return 1
        case .quickActions: return 2
        case .accounts: return 3
        case .other: return 3
        case .credits: return 4
        }
    }

    var description: String {
        switch self {
        case .theme:
            return NSLocalizedString("SettingsViewController_Table_Header_Theme", comment: "")
        case .refresh:
            return NSLocalizedString("SettingsViewController_Table_Header_Refresh", comment: "")
        case .quickActions:
            return NSLocalizedString("SettingsViewController_Table_Header_QuickActions", comment: "")
        case .accounts:
            return NSLocalizedString("SettinsgViewController_Table_Header_Accounts", comment: "")
        case .other:
            return NSLocalizedString("SettingsViewController_Table_Header_Other", comment: "")
        case .credits:
            return NSLocalizedString("SettingsViewController_Table_Header_Credits", comment: "")
        }
    }
}

enum OtherSection: Int, CustomStringConvertible {
    case showReadingTimes = 0
    case exportOPML = 1

    var description: String {
        switch self {
        case .showReadingTimes:
            return NSLocalizedString("SettingsViewController_Other_ShowReadingTimes", comment: "")
        case .exportOPML:
            return NSLocalizedString("SettingsViewController_Other_ExportOPML", comment: "")
        }
    }

    static let numberOfOptions = 2
}
