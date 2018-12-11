import Quick
import Nimble
import Foundation
import UIKit
@testable import TethysKit

fileprivate class FakeBackgroundStateReceiver: BackgroundStateReceiver {
    var didEnterForegroundCalled = false
    fileprivate func didEnterForeground() {
        self.didEnterForegroundCalled = true
    }

    var willEnterBackgroundCalled = false
    fileprivate func willEnterBackground() {
        self.willEnterBackgroundCalled = true
    }
}

class BackgroundStateMonitorSpec: QuickSpec {
    override func spec() {
        var subject: BackgroundStateMonitor!
        var notificationCenter: NotificationCenter!
        var receiver: FakeBackgroundStateReceiver!

        beforeEach {
            notificationCenter = NotificationCenter()

            subject = BackgroundStateMonitor(notificationCenter: notificationCenter)

            receiver = FakeBackgroundStateReceiver()
            subject.addReceiver(receiver: receiver)
        }

        it("removes itself as an observer when it's dealloc'd") {
            subject = nil

            expect(notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil, userInfo: nil)).toNot(raiseException())
            expect(notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil, userInfo: nil)).toNot(raiseException())

            expect(receiver.willEnterBackgroundCalled) == false
            expect(receiver.didEnterForegroundCalled) == false
        }

        it("forwards will resign active to it's receivers") {
            notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil, userInfo: nil)

            expect(receiver.willEnterBackgroundCalled) == true
        }

        it("forwards did become active to it's receivers") {
            notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil, userInfo: nil)

            expect(receiver.didEnterForegroundCalled) == true
        }
    }
}
