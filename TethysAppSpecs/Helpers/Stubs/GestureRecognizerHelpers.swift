import UIKit
import Quick
import Nimble

@testable import Tethys

@objc final class GestureObserver: NSObject {
    var observationCount = 0
    @objc func didRecognize(_ recognizer: UIGestureRecognizer) {
        self.observationCount += 1
    }
}

extension UIGestureRecognizer {
    func setupForTest() -> GestureObserver {
        let observer = GestureObserver()
        self.addTarget(observer, action: #selector(GestureObserver.didRecognize(_:)))
        return observer
    }

    func beginForTest(point: CGPoint, observer: GestureObserver, line: UInt = #line, file: String = #file) {
        let observerCount = observer.observationCount
        let touch = FakeTouch()
        touch.currentLocation = point

        self.touchesBegan([touch], with: UIEvent())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        expect(observer.observationCount, file: file, line: line).toEventually(equal(observerCount + 1))
    }

    func updateForTest(point: CGPoint, observer: GestureObserver, line: UInt = #line, file: String = #file) {
        let observerCount = observer.observationCount
        let touch = FakeTouch()
        touch.currentLocation = point
        self.touchesMoved([touch], with: UIEvent())

        expect(observer.observationCount, file: file, line: line).toEventually(equal(observerCount + 1))
    }

    func endForTest(observer: GestureObserver, line: UInt = #line, file: String = #file) {
        let observerCount = observer.observationCount
        self.touchesEnded([], with: UIEvent())

        expect(observer.observationCount, file: file, line: line).toEventually(equal(observerCount + 1))
    }
}
