import rNews
import UIKit

class FakeNotificationSource: LocalNotificationSource {
    var scheduledNotes: [UILocalNotification] = []
    var notificationSettings: UIUserNotificationSettings? = nil

    var canScheduleNote = true

    func scheduleNote(note: UILocalNotification) {
        scheduledNotes.append(note)
    }

    init() {}
}