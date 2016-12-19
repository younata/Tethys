import Foundation

struct KVONotification {
    let keyPath: String?
    let sender: Any?
    let change: [NSKeyValueChangeKey: Any]?
}

final class KVOMonitor: NSObject {
    var receivedNotifications: [KVONotification] = []

    func monitor(object: NSObject, keyPath: String, changes: NSKeyValueObservingOptions) {
        object.addObserver(self, forKeyPath: keyPath, options: changes, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        self.receivedNotifications.append(KVONotification(keyPath: keyPath, sender: object, change: change))
    }
}
