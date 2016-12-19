import Foundation
import Ra

public final class SyncManager: Injectable {
    let workQueue: OperationQueue
    let mainQueue: OperationQueue
    let backgroundStateMonitor: BackgroundStateMonitor

    init(workQueue: OperationQueue, mainQueue: OperationQueue, backgroundStateMonitor: BackgroundStateMonitor) {
        self.workQueue = workQueue
        self.mainQueue = mainQueue
        self.backgroundStateMonitor = backgroundStateMonitor
    }

    public required convenience init(injector: Injector) {
        self.init(
            workQueue: injector.create(kind: OperationQueue.self)!,
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue,
            backgroundStateMonitor: injector.create(kind: BackgroundStateMonitor.self)!
        )
    }

    public func refresh(userRequested: Bool = false) {
//        let priority: QualityOfService = userRequested ? .userInitiated : .background
    }

    public func update(article: Article) {
        // always background work
    }
}
