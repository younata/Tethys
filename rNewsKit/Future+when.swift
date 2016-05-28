import CBGPromise

extension Promise {
    class func rnews_when<T>(futures: [Future<T>]) -> Future<[T]> {
        let promise = Promise<[T]>()
        var values: [T] = []

        values.reserveCapacity(futures.count)
        var currentCount = 0

        for (idx, future) in futures.enumerate() {
            future.then {
                values[idx] = $0
                currentCount += 1
                if currentCount == futures.count {
                    promise.resolve(values)
                }
            }
        }
        return promise.future
    }
}
