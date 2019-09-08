import UIKit
import TethysKit

enum SettingsSection: Int, CustomStringConvertible {
    case account = -1
    case theme = 0
    case refresh = 1
    case other = 2
    case credits = 3

    static func numberOfSettings() -> Int {
        return 4 //5
    }

    var rawValue: Int {
        switch self {
        case .account: return 0
        case .theme: return 0
        case .refresh: return 1
        case .other: return 2
        case .credits: return 3
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
    case gitVersion = 2

    var description: String {
        switch self {
        case .showReadingTimes:
            return NSLocalizedString("SettingsViewController_Other_ShowReadingTimes", comment: "")
        case .exportOPML:
            return NSLocalizedString("SettingsViewController_Other_ExportOPML", comment: "")
        case .gitVersion:
            return NSLocalizedString("SettingsViewController_Credits_Version", comment: "")
        }

    }

    static let numberOfOptions = 3
}
