import Foundation
import CBGPromise

public final class FutureOperation: Operation {
    private let kickOff: (Void) -> (Future<Void>)
    public init(kickOff: @escaping (Void) -> (Future<Void>)) {
        self.kickOff = kickOff

        super.init()
    }

    private let isExecutingKey = "isExecuting"
    private let isFinishedKey = "isFinished"

    private var _isExecuting = false
    public override var isExecuting: Bool {
        return self._isExecuting
    }

    private var _isFinished = false
    public override var isFinished: Bool {
        return self._isFinished
    }

    public override var isAsynchronous: Bool {
        return true
    }

    public override func start() {
        self.willChangeValue(forKey: self.isExecutingKey)

        _ = self.kickOff().then {
            self.willChangeValue(forKey: self.isExecutingKey)
            self._isExecuting = false
            self.didChangeValue(forKey: self.isExecutingKey)

            self.willChangeValue(forKey: self.isFinishedKey)
            self._isFinished = true
            self.didChangeValue(forKey: self.isFinishedKey)
        }

        self._isExecuting = true

        self.didChangeValue(forKey: self.isExecutingKey)
    }
}
