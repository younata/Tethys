import CBGPromise
import Result

public protocol ArticleService {
    func feed(of article: Article) -> Future<Result<Feed, TethysError>>
    func authors(of article: Article) -> String
}

import RealmSwift

final class RealmArticleService: ArticleService {
    private let realmProvider: RealmProvider
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(realmProvider: RealmProvider, mainQueue: OperationQueue, workQueue: OperationQueue) {
        self.realmProvider = realmProvider
        self.mainQueue = mainQueue
        self.workQueue = workQueue
    }

    func feed(of article: Article) -> Future<Result<Feed, TethysError>> {
        let promise = Promise<Result<Feed, TethysError>>()
        self.workQueue.addOperation {
            guard let feed = self.realmArticle(for: article)?.feed else {
                self.mainQueue.addOperation {
                    promise.resolve(.failure(TethysError.database(DatabaseError.entryNotFound)))
                }
                return
            }
            self.mainQueue.addOperation {
                promise.resolve(.success(Feed(realmFeed: feed)))
            }
        }
        return promise.future
    }

    func authors(of article: Article) -> String {
        return article.authors.map { $0.description }.joined(separator: ", ")
    }

    private func realmArticle(for article: Article) -> RealmArticle? {
        return self.realmProvider.realm().object(ofType: RealmArticle.self, forPrimaryKey: article.identifier)
    }
}
