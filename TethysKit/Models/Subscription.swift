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

public class Subscription<T> {
    private var callbacks: [(T) -> Void] = []
    public private(set) var value: T?

    public private(set) var isFinished = false

    fileprivate func update(with value: T) {
        self.value = value
        callbacks.forEach { $0(value) }
    }

    func finish() {
        self.callbacks = []
        self.isFinished = true
    }

    public func then(_ block: @escaping (T) -> Void) {
        self.callbacks.append(block)

        if let value = self.value {
            block(value)
        }
    }
}
