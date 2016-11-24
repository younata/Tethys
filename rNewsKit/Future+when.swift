import CBGPromise

extension Promise {
    class func rnews_when<T>(_ futures: [Future<T>]) -> Future<[T]> {
        let promise = Promise<[T]>()
        var values: [T?] = futures.map { _ in nil }

        var currentCount = 0

        for (idx, future) in futures.enumerated() {
            _ = future.then {
                values[idx] = $0
                currentCount += 1
                if currentCount == futures.count {
                    promise.resolve(values.flatMap { $0 })
                }
            }
        }
        return promise.future
    }
}
