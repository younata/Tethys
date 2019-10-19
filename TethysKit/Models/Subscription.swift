public class Publisher<T> {
    public let subscription = Subscription<T>()

    public func update(with value: T) {
        self.subscription.update(with: value)
    }
    public func finish() {
        self.subscription.finish()
    }
}

public class Subscription<T> {
    private var callbacks: [(T) -> Void] = []
    private var lastValue: T?

    fileprivate func update(with value: T) {
        self.lastValue = value
        callbacks.forEach { $0(value) }
    }

    func finish() {
        self.callbacks = []
    }

    public func then(_ block: @escaping (T) -> Void) {
        self.callbacks.append(block)

        if let value = self.lastValue {
            block(value)
        }
    }
}
