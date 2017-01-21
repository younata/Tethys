import Foundation

public protocol TimerFactory {
    func nonrepeatingTimer(fireDate: Date, tolerance: TimeInterval, block: @escaping (Timer) -> Void)
}

struct DefaultTimerFactory: TimerFactory {
    func nonrepeatingTimer(fireDate: Date, tolerance: TimeInterval, block: @escaping (Timer) -> Void) {
        let timer = Timer(fire: fireDate, interval: 0, repeats: false, block: block)
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .defaultRunLoopMode)
    }
}
