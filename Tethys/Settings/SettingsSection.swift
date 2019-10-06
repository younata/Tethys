import UIKit
import TethysKit

enum SettingsSection: Int, CustomStringConvertible {
    case account = 0
    case refresh = 1
    case other = 2
    case credits = 3

    static func numberOfSettings() -> Int {
        return 4
    }

    var rawValue: Int {
        switch self {
        case .account: return 0
        case .refresh: return 1
        case .other: return 2
        case .credits: return 3
        }
    }

    var description: String {
        switch self {
        case .account:
            return NSLocalizedString("SettingsViewController_Table_Header_Account", comment: "")
        case .refresh:
            return NSLocalizedString("SettingsViewController_Table_Header_Refresh", comment: "")
        case .other:
            return NSLocalizedString("SettingsViewController_Table_Header_Other", comment: "")
        case .credits:
            return NSLocalizedString("SettingsViewController_Table_Header_Credits", comment: "")
        }
    }
}

enum OtherSection: CustomStringConvertible {
    case showReadingTimes
    case exportOPML
    case appIcon
    case gitVersion

    var description: String {
        switch self {
        case .showReadingTimes:
            return NSLocalizedString("SettingsViewController_Other_ShowReadingTimes", comment: "")
        case .exportOPML:
            return NSLocalizedString("SettingsViewController_Other_ExportOPML", comment: "")
        case .appIcon:
            return NSLocalizedString("SettingsViewController_AlternateIcons_Title", comment: "")
        case .gitVersion:
            return NSLocalizedString("SettingsViewController_Credits_Version", comment: "")
        }
    }

    init?(rowIndex: Int, appIconChanger: AppIconChanger) {
        switch rowIndex {
        case 0: self = .showReadingTimes
        case 1: self = .exportOPML
        case 2:
            if appIconChanger.supportsAlternateIcons {
                self = .appIcon
            } else {
                self = .gitVersion
            }
        case 3:
            if appIconChanger.supportsAlternateIcons {
                self = .gitVersion
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    func rowIndex(appIconChanger: AppIconChanger) -> Int {
        switch self {
        case .showReadingTimes: return 0
        case .exportOPML: return 1
        case .appIcon: return 2
        case .gitVersion: return appIconChanger.supportsAlternateIcons ? 3 : 2
        }
    }

    static func numberOfOptions(appIconChanger: AppIconChanger) -> Int {
        guard appIconChanger.supportsAlternateIcons else {
            return 3
        }
        return 4
    }
}
