import Foundation
import UIKit
import Ra

public protocol BackgroundStateReceiver: class {
    func willEnterBackground()
    func didEnterForeground()
}

public final class BackgroundStateMonitor: NSObject, Injectable {
    private let notificationCenter: NotificationCenter

    private let receivers = NSHashTable<AnyObject>.weakObjects()
    private var allReceivers: [BackgroundStateReceiver] {
        return self.receivers.allObjects.flatMap { $0 as? BackgroundStateReceiver }
    }

    public func addReceiver(receiver: BackgroundStateReceiver) {
        self.receivers.add(receiver)
    }

    public init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()
        notificationCenter.addObserver(self, selector: #selector(BackgroundStateMonitor.willEnterBackground),
                                       name: .UIApplicationWillResignActive, object: nil)
        notificationCenter.addObserver(self, selector: #selector(BackgroundStateMonitor.didEnterForeground),
                                       name: .UIApplicationDidBecomeActive, object: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            notificationCenter: injector.create(kind: NotificationCenter.self)!
        )
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    @objc private func willEnterBackground() {
        self.allReceivers.forEach { $0.willEnterBackground() }
    }

    @objc private func didEnterForeground() {
        self.allReceivers.forEach { $0.didEnterForeground() }
    }
}
