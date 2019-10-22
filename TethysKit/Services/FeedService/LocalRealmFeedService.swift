import Result
import CBGPromise
import RealmSwift

struct LocalRealmFeedService: LocalFeedService {
    private let realmProvider: RealmProvider
    private let updateService: UpdateService
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(realmProvider: RealmProvider,
         updateService: UpdateService,
         mainQueue: OperationQueue,
         workQueue: OperationQueue) {
        self.realmProvider = realmProvider
        self.updateService = updateService
        self.mainQueue = mainQueue
        self.workQueue = workQueue
    }

    // MARK: FeedService Conformance
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Feed>, TethysError>>()
        self.workQueue.addOperation {
            let realmFeeds = self.realmProvider.realm().objects(RealmFeed.self)
            let feeds = realmFeeds
                .map { Feed(realmFeed: $0) }
                .sorted { (lhs, rhs) -> Bool in
                    guard lhs.unreadCount == rhs.unreadCount else {
                        return lhs.unreadCount > rhs.unreadCount
                    }
                    return lhs.title < rhs.title
                }
            self.resolve(promise: promise, with: AnyCollection(feeds))
        }
        return promise.future
    }

    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Article>, TethysError>>()
        self.workQueue.addOperation {
            guard let realmFeed = self.realmFeed(for: feed) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            let articles = realmFeed.articles.sorted(by: [
                SortDescriptor(keyPath: "published", ascending: false)
            ])
            return self.resolve(
                promise: promise,
                with: AnyCollection(Array(articles.map { Article(realmArticle: $0)} ))
            )
        }
        return promise.future
    }

    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        let promise = Promise<Result<Feed, TethysError>>()
        self.workQueue.addOperation {
            let predicate = NSPredicate(format: "url == %@", url.absoluteString)
            if let realmFeed = self.realmProvider.realm().objects(RealmFeed.self).filter(predicate).first {
                return self.resolve(promise: promise, with: Feed(realmFeed: realmFeed))
            }

            let realm = self.realmProvider.realm()
            realm.beginWrite()
            let feed = RealmFeed()
            feed.url = url.absoluteString

            realm.add(feed)

            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                return self.resolve(promise: promise, error: .database(.unknown))
            }
            self.resolve(promise: promise, with: Feed(realmFeed: feed))
        }
        return promise.future
    }

    func tags() -> Future<Result<AnyCollection<String>, TethysError>> {
        return Promise<Result<AnyCollection<String>, TethysError>>.resolved(.failure(.notSupported))
    }

    func set(tags: [String], of feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>.resolved(.failure(.notSupported))
    }

    func set(url: URL, on feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>.resolved(.failure(.notSupported))
    }

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        return self.write(feed: feed) { realmFeed in
            realmFeed.articles.filter("read == false").forEach { $0.read = true }
            return Void()
        }
    }

    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        return self.write(feed: feed) { realmFeed in
            self.realmProvider.realm().delete(realmFeed)
            return Void()
        }.map { (result: Result<Void, TethysError>) -> Result<Void, TethysError> in
            switch result {
            case .success, .failure(.database(.entryNotFound)):
                return .success(Void())
            default:
                return result
            }
        }
    }

    // MARK: LocalFeedService Conformance
    func updateFeeds(with feeds: AnyCollection<Feed>) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>().future
    }

    func updateFeed(from feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    // MARK: Private methods
    private func write<T>(feed: Feed,
                          transaction: @escaping (RealmFeed) -> T) -> Future<Result<T, TethysError>> {
        let promise = Promise<Result<T, TethysError>>()
        self.workQueue.addOperation {
            guard let realmFeed = self.realmFeed(for: feed) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            let realm = self.realmProvider.realm()
            realm.beginWrite()

            let value: T = transaction(realmFeed)

            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                return self.resolve(promise: promise, error: .database(.unknown))
            }

            return self.resolve(promise: promise, with: value)
        }
        return promise.future
    }

    private func realmFeed(for feed: Feed) -> RealmFeed? {
        return self.realmProvider.realm().object(ofType: RealmFeed.self, forPrimaryKey: feed.identifier)
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
