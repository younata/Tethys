import Foundation
import TethysKit

class FakeTimerFactory: TimerFactory {
    var nonrepeatingTimerCallCount = 0
    private var nonrepeatingTimerArgs: [(Date, TimeInterval, (Timer) -> Void)] = []
    func nonrepeatingTimerArgsForCall(_ callIndex: Int) -> (Date, TimeInterval, (Timer) -> Void) {
        return self.nonrepeatingTimerArgs[callIndex]
    }
    func nonrepeatingTimer(fireDate: Date, tolerance: TimeInterval, block: @escaping (Timer) -> Void) {
        self.nonrepeatingTimerCallCount += 1
        self.nonrepeatingTimerArgs.append((fireDate, tolerance, block))
    }
}
