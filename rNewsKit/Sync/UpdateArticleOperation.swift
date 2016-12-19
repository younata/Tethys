import Foundation
import Sinope
import CBGPromise
import Result

final class UpdateArticleOperation: Operation {
    private let article: Article
    private let backendRepository: Sinope.Repository

    private var updateFuture: Future<Result<Void, SinopeError>>?

    private let isExecutingKey = "isExecuting"
    private let isFinishedKey = "isFinished"

    init(article: Article, backendRepository: Sinope.Repository) {
        self.article = article
        self.backendRepository = backendRepository
        super.init()
    }

    private var _isExecuting = false
    override var isExecuting: Bool {
        return self._isExecuting
    }

    private var _isFinished = false
    override var isFinished: Bool {
        return self._isFinished
    }

    override var isAsynchronous: Bool {
        return true
    }

    override func start() {
        self.willChangeValue(forKey: self.isExecutingKey)

        self.article.synced = false
        self.updateFuture = self.backendRepository.markRead(articles: [self.article.link: self.article.read]).then {
            switch $0 {
            case .success():
                self.article.synced = true
                self.finishOperation()
            case .failure(_):
                self.finishOperation()
            }
        }

        self._isExecuting = true

        self.didChangeValue(forKey: self.isExecutingKey)
    }

    private func finishOperation() {
        self.willChangeValue(forKey: self.isExecutingKey)
        self._isExecuting = false
        self.didChangeValue(forKey: self.isExecutingKey)

        self.willChangeValue(forKey: self.isFinishedKey)
        self._isFinished = true
        self.didChangeValue(forKey: self.isFinishedKey)
    }
}
