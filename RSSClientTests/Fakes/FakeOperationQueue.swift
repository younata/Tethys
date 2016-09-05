import Foundation

class FakeOperationQueue: OperationQueue {
    var runSynchronously: Bool = false

    func reset() {
        internalOperations = []
    }

    func runNextOperation() {
        assert(internalOperations.count != 0, "Can't run an operation that doesn't exist")
        if let op = internalOperations.first {
            performOperationAndWait(op)
            internalOperations.remove(at: 0)
        }
    }

    override func addOperation(_ op: Operation) {
        if runSynchronously {
            performOperationAndWait(op)
        } else {
            internalOperations.append(op)
        }
    }

    override func addOperations(_ operations: [Operation], waitUntilFinished wait: Bool) {
        let oldRunSynchronously = runSynchronously
        runSynchronously = runSynchronously || wait
        for op in operations {
            addOperation(op)
        }
        runSynchronously = oldRunSynchronously
    }

    override func addOperation(_ block: @escaping () -> Void) {
        addOperation(BlockOperation(block: block))
    }

    override func cancelAllOperations() {
        for op in internalOperations {
            op.cancel()
        }
        reset()
    }

    override init() {
        super.init()
        isSuspended = true
        reset()
    }

    var internalOperations: [Operation] = []

    override var operationCount: Int {
        return internalOperations.count
    }

    private func performOperationAndWait(_ op: Operation) {
        op.start()
        op.waitUntilFinished()
    }
}
