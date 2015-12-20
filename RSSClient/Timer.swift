import Foundation

public class Timer: NSObject {
    private var timer: NSTimer? = nil
    private var callback: (Void) -> (Void) = {}

    public func setTimer(interval: NSTimeInterval, callback: (Void) -> (Void)) {
        if self.timer != nil {
            self.timer?.invalidate()
        }
        self.callback = callback
        self.timer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: "timerWentOff", userInfo: nil, repeats: false)
    }

    public func cancel() {
        self.timer?.invalidate()
    }

    @objc private func timerWentOff() {
        self.callback()
        self.timer?.invalidate()
        self.timer = nil
    }
}