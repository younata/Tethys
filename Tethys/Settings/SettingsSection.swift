import UIKit
import TethysKit

enum SettingsSection: Int, CustomStringConvertible {
    case account
    case theme
    case refresh
    case other
    case credits

    static func numberOfSettings(_ traits: UITraitCollection) -> Int {
        return 5
    }

    var rawValue: Int {
        switch self {
        case .account: return 0
        case .theme: return 1
        case .refresh: return 2
        case .other: return 3
        case .credits: return 4
        }
    }

    var description: String {
        switch self {
        case .account:
            return NSLocalizedString("SettingsViewController_Table_Header_Account", comment: "")
        case .theme:
            return NSLocalizedString("SettingsViewController_Table_Header_Theme", comment: "")
        case .refresh:
            return NSLocalizedString("SettingsViewController_Table_Header_Refresh", comment: "")
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
