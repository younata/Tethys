import Tethys
import TethysKit

import Foundation

final class FakeNotificationHandler : NotificationHandler {
    init() {
    }

    private(set) var enableNotificationsCalls: [LocalNotificationSource] = []
    func enableNotifications(_ notificationSource: LocalNotificationSource) {
        self.enableNotificationsCalls.append((notificationSource))
    }

    private(set) var handleLocalNotificationCalls: [(UILocalNotification, UIWindow)] = []
    func handleLocalNotification(_ notification: UILocalNotification, window: UIWindow) {
        self.handleLocalNotificationCalls.append((notification, window))
    }

    private(set) var handleActionCalls: [(String?, UILocalNotification)] = []
    func handleAction(_ identifier: String?, notification: UILocalNotification) {
        self.handleActionCalls.append((identifier, notification))
    }

    private(set) var sendLocalNotificationCalls: [(LocalNotificationSource, Article)] = []
    func sendLocalNotification(_ notificationSource: LocalNotificationSource, article: Article) {
        self.sendLocalNotificationCalls.append((notificationSource, article))
    }

    static func reset() {
    }
}
