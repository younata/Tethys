import UIKit

public protocol LocalNotificationSource {
    var scheduledNotes: [UILocalNotification] { get }
    var notificationSettings: UIUserNotificationSettings? { get set }

    func scheduleNote(note: UILocalNotification)
}

extension UIApplication: LocalNotificationSource {
    public var scheduledNotes: [UILocalNotification] {
        return self.scheduledLocalNotifications ?? []
    }

    public var notificationSettings: UIUserNotificationSettings? {
        get {
            return self.currentUserNotificationSettings()
        }
        set {
            if let newSettings = newValue {
                self.registerUserNotificationSettings(newSettings)
            }
        }
    }

    public func scheduleNote(note: UILocalNotification) {
        if self.applicationState != .Active {
            self.scheduleLocalNotification(note)
        }
    }
}