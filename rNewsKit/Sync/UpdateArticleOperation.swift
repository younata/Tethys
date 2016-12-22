import Foundation
import Sinope
import CBGPromise
import Result

final class UpdateArticleOperation: Operation {
    let articles: [Article]
    private let backendRepository: Sinope.Repository

    private var updateFuture: Future<Result<Void, SinopeError>>?

    var onCompletion: ((Result<Void, SinopeError>) -> (Void))? {
        didSet {
            self.runCompletionIfAvailable()
        }
    }

    private let isExecutingKey = "isExecuting"
    private let isFinishedKey = "isFinished"

    init(articles: [Article], backendRepository: Sinope.Repository) {
        self.articles = articles
        self.backendRepository = backendRepository
        super.init()
    }

    private func runCompletionIfAvailable() {
        if let completion = self.onCompletion, let result = self.updateFuture?.value {
            completion(result)
        }
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

        self.articles.forEach { $0.synced = false }

        let markReadDictionary: [URL: Bool] = self.articles.reduce([:]) {
            var dict = $0
            dict[$1.link] = $1.read
            return dict
        }
        self.updateFuture = self.backendRepository.markRead(articles: markReadDictionary)

        _ = self.updateFuture?.then {
            switch $0 {
            case .success():
                self.articles.forEach { $0.synced = true }
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

        self.runCompletionIfAvailable()

        self.willChangeValue(forKey: self.isFinishedKey)
        self._isFinished = true
        self.didChangeValue(forKey: self.isFinishedKey)
    }
}
