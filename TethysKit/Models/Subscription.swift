public class Publisher<T> {
    public let subscription = Subscription<T>()

    public private(set) var isFinished = false

    public func update(with value: T) {
        guard self.isFinished == false else { return }
        self.subscription.update(with: value)
    }
    public func finish() {
        self.subscription.finish()
        self.isFinished = true
    }
}

public enum SubscriptionUpdate<T> {
    case update(T)
    case finished
}

extension SubscriptionUpdate: Equatable where T: Equatable {}

public class Subscription<T> {
    private var callbacks: [(SubscriptionUpdate<T>) -> Void] = []
    public private(set) var value: T?

    public private(set) var isFinished = false

    fileprivate func update(with value: T) {
        self.value = value
        callbacks.forEach { $0(.update(value)) }
    }

    func finish() {
        self.callbacks.forEach { $0(.finished) }
        self.callbacks = []
        self.isFinished = true
    }

    public func then(_ block: @escaping (SubscriptionUpdate<T>) -> Void) {
        self.callbacks.append(block)

        if let value = self.value {
            block(.update(value))
        }
    }
}
