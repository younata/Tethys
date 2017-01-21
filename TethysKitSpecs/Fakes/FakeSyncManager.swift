import Foundation
@testable import TethysKit

class FakeSyncManager: SyncManager {
    var updateAllUnsyncedArticlesCallCount = 0
    func updateAllUnsyncedArticles() {
        self.updateAllUnsyncedArticlesCallCount += 1
    }

    var updateArticlesCallCount = 0
    private var updateArticlesArgs: [[Article]] = []
    func updateArticlesArgsForCall(_ callIndex: Int) -> [Article] {
        return self.updateArticlesArgs[callIndex]
    }
    func update(articles: [Article]) {
        self.updateArticlesCallCount += 1
        self.updateArticlesArgs.append(articles)
    }
}
