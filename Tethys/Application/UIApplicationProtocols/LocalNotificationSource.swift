import UIKit

public protocol LocalNotificationSource: class {
    var scheduledNotes: [UILocalNotification] { get }
    var notificationSettings: UIUserNotificationSettings? { get set }
    var canScheduleNote: Bool { get }

    func scheduleNote(_ note: UILocalNotification)
}

extension UIApplication: LocalNotificationSource {
    public var scheduledNotes: [UILocalNotification] {
        return self.scheduledLocalNotifications ?? []
    }

    public var notificationSettings: UIUserNotificationSettings? {
        get {
            return self.currentUserNotificationSettings
        }
        set {
            if let newSettings = newValue {
                self.registerUserNotificationSettings(newSettings)
            }
        }
    }

    public var canScheduleNote: Bool {
        return self.applicationState == .background
    }

    public func scheduleNote(_ note: UILocalNotification) {
        if self.canScheduleNote {
            self.scheduleLocalNotification(note)
        }
    }
}