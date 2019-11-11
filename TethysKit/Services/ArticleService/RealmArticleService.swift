import Result
import CBGPromise
import RealmSwift

struct RealmArticleService: ArticleService {
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
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }
            return self.resolve(promise: promise, with: Feed(realmFeed: feed))
        }
        return promise.future
    }

    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>> {
        let promise = Promise<Result<Article, TethysError>>()
        guard article.read != read else {
            promise.resolve(.success(article))
            return promise.future
        }
        self.workQueue.addOperation {
            guard let realmArticle = self.realmArticle(for: article) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }
            let realm = self.realmProvider.realm()
            realm.beginWrite()
            realmArticle.read = read
            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
            }
            self.resolve(promise: promise, with: Article(realmArticle: realmArticle))
        }
        return promise.future
    }

    func remove(article: Article) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        self.workQueue.addOperation {
            guard let realmArticle = self.realmArticle(for: article) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }
            let realm = self.realmProvider.realm()
            realm.beginWrite()
            realm.delete(realmArticle)
            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                return self.resolve(promise: promise, error: .database(.unknown))
            }
            return self.resolve(promise: promise, with: Void())
        }
        return promise.future
    }

    func authors(of article: Article) -> String {
        return article.authors.map { $0.description }.joined(separator: ", ")
    }

    func date(for article: Article) -> Date {
        let realmArticle = self.realmArticle(for: article)
        return realmArticle?.date ?? Date()
    }

    func estimatedReadingTime(of article: Article) -> TimeInterval {
        guard let realmArticle = self.realmArticle(for: article) else { return 0 }
        if realmArticle.estimatedReadingTime > 0 {
            return realmArticle.estimatedReadingTime
        }
        let text = realmArticle.content?.optional ?? realmArticle.summary?.optional ?? ""
        let readingTime = self.estimateReadingTime(text)
        self.saveReadingTime(readingTime, for: article)
        return readingTime
    }

    private func estimateReadingTime(_ htmlString: String) -> TimeInterval {
        let words = htmlString.stringByStrippingHTML().components(separatedBy: " ")

        let wordsPerSecond: TimeInterval = 10.0 / 3.0 // 200 words per minute / 60 seconds per minute
        return TimeInterval(words.count) / wordsPerSecond
    }

    private func realmArticle(for article: Article) -> RealmArticle? {
        let predicate = NSPredicate(format: "link == %@", article.link.absoluteString)
        return self.realmProvider.realm().objects(RealmArticle.self).filter(predicate).first
    }

    private func saveReadingTime(_ readingTime: TimeInterval, for article: Article) {
        self.workQueue.addOperation {
            let realm = self.realmProvider.realm()
            guard let realmArticle = self.realmArticle(for: article) else { return }
            realm.beginWrite()
            realmArticle.estimatedReadingTime = readingTime
            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
            }
        }
    }

    private func resolve<T>(promise: Promise<Result<T, TethysError>>, with value: T? = nil, error: TethysError? = nil) {
        self.mainQueue.addOperation {
            let result: Result<T, TethysError>
            if let value = value {
                result = Result<T, TethysError>.success(value)
            } else if let error = error {
                result = Result<T, TethysError>.failure(error)
            } else {
                fatalError("Called resolve with two nil arguments")
            }

            promise.resolve(result)
        }
    }
}
