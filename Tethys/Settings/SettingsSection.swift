import UIKit
import TethysKit

enum SettingsSection: Int, CustomStringConvertible {
    case theme
    case refresh
    case other
    case credits

    static func numberOfSettings(_ traits: UITraitCollection) -> Int {
        return 4
    }

    var rawValue: Int {
        switch self {
        case .theme: return 0
        case .refresh: return 1
        case .other: return 2
        case .credits: return 3
        }
    }

    var description: String {
        switch self {
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
