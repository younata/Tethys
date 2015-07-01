import Foundation

// Because PivotalCoreKit doesn't support Carthage, and I don't want to put in that effort yet.

class FakeOperationQueue : NSOperationQueue {
    var runSynchronously : Bool = false

    func reset() {
        internalOperations = []
    }

    func runNextOperation() {
        assert(internalOperations.count != 0, "Can't run an operation that doesn't exist")
        if let op = internalOperations.first {
            performOperationAndWait(op)
            internalOperations.removeAtIndex(0)
        }
    }

    override func addOperation(op: NSOperation) {
        if runSynchronously {
            performOperationAndWait(op)
        } else {
            internalOperations.append(op)
        }
    }

    override func addOperations(operations: [NSOperation], waitUntilFinished wait: Bool) {
        let oldRunSynchronously = runSynchronously
        runSynchronously = runSynchronously || wait
        for op in operations {
            addOperation(op)
        }
        runSynchronously = oldRunSynchronously
    }

    override func addOperationWithBlock(block: () -> Void) {
        addOperation(NSBlockOperation(block: block))
    }

    override func cancelAllOperations() {
        for op in internalOperations {
            op.cancel()
        }
        reset()
    }

    override init() {
        super.init()
        suspended = true
        reset()
    }

    var internalOperations : [NSOperation] = []

    override var operationCount: Int {
        return internalOperations.count
    }

    private func performOperationAndWait(op: NSOperation) {
        op.start()
        op.waitUntilFinished()
    }
}
