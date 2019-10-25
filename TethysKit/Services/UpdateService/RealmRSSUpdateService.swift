import Muon
import Result
import CBGPromise
import FutureHTTP

final class RealmRSSUpdateService: UpdateService {
    private let httpClient: HTTPClient
    private let realmProvider: RealmProvider
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(httpClient: HTTPClient, realmProvider: RealmProvider, mainQueue: OperationQueue, workQueue: OperationQueue) {
        self.httpClient = httpClient
        self.realmProvider = realmProvider
        self.mainQueue = mainQueue
        self.workQueue = workQueue
    }

    func updateFeed(_ feed: Feed) -> Future<Result<Feed, TethysError>> {
        let identifier = feed.identifier
        let promise = Promise<Result<Feed, TethysError>>()
        self.workQueue.addOperation {
            guard self.realmProvider.realm().object(ofType: RealmFeed.self, forPrimaryKey: identifier) != nil else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            self.fetch(url: feed.url).map {
                return $0.mapFuture { data -> Future<Result<Muon.Feed, TethysError>> in
                    return self.parse(feed: data)
                }
            }.map {
                return $0.mapFuture { muonFeed -> Future<Result<Feed, TethysError>> in
                    return self.update(from: muonFeed, identifier: identifier, fallbackURL: feed.url)
                }
            }.then { result in
                promise.resolve(result)
            }
        }
        return promise.future
    }

    private func fetch(url: URL) -> Future<Result<Data, TethysError>> {
        return self.httpClient.request(URLRequest(url: url)).map { result -> Result<Data, TethysError> in
            switch result {
            case .success(let response):
                return .success(response.body)
            case .failure(let failure):
                let error: NetworkError
                switch failure {
                case .http, .url, .security, .unknown:
                    error = NetworkError.unknown
                case .network(let network):
                    error = self.convert(networkError: network)
                }
                return .failure(.network(url, error))
            }
        }
    }

    private func parse(feed data: Data) -> Future<Result<Muon.Feed, TethysError>> {
        let promise = Promise<Result<Muon.Feed, TethysError>>()
        let parser = FeedParser(string: String(data: data, encoding: .utf8)!).success {
            guard promise.future.value == nil else {
                print("Error: Resolving promise twice - currently \(String(describing: promise.future.value))")
                return
            }
            promise.resolve(.success($0))
        }.failure { error in
            dump(error)
            guard promise.future.value == nil else {
                print("Error: Resolving promise twice - currently \(String(describing: promise.future.value))")
                return
            }

            promise.resolve(.failure(.unknown))
        }
        self.workQueue.addOperation(parser)
        return promise.future
    }

    private func convert(networkError: FutureHTTP.NetworkError) -> TethysKit.NetworkError {
        switch networkError {
        case .cancelled:
            return .cancelled
        case .cannotFindHost, .cannotConnectTohost:
            return .serverNotFound
        case .connectionLost:
            return .internetDown
        case .dnsFailed:
            return .dns
        case .notConnectedToInternet:
            return .internetDown
        case .timedOut:
            return .timedOut

        }
    }

    private func update(from muonFeed: Muon.Feed, identifier: String, fallbackURL: URL) -> Future<Result<Feed, TethysError>> {
        let promise = Promise<Result<Feed, TethysError>>()
        self.workQueue.addOperation {
            guard let feed = self.realmProvider.realm().object(ofType: RealmFeed.self, forPrimaryKey: identifier) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            self.realmProvider.realm().beginWrite()

            feed.title = muonFeed.title
            feed.summary = muonFeed.description

            muonFeed.articles.forEach {
                self.upsert(article: $0, to: feed, feedURL: muonFeed.link ?? fallbackURL)
            }

            do {
                try self.realmProvider.realm().commitWrite()
            } catch let error {
                dump(error)
                return self.resolve(promise: promise, error: .database(.unknown))
            }
            guard let imageURL = muonFeed.imageURL, feed.imageData == nil else {
                return self.resolve(promise: promise, with: Feed(realmFeed: feed))
            }
            return self.fetchImage(url: imageURL, identifier: identifier, promise: promise)
        }
        return promise.future
    }

    private func fetchImage(url: URL, identifier: String, promise: Promise<Result<Feed, TethysError>>) {
        self.fetch(url: url).then { result in
            switch result {
            case .success(let data):
                guard let realmFeed = self.realmProvider.realm().object(ofType: RealmFeed.self,
                                                                        forPrimaryKey: identifier) else {
                    return self.resolve(promise: promise, error: .database(.entryNotFound))
                }

                self.realmProvider.realm().beginWrite()

                realmFeed.imageData = data

                do {
                    try self.realmProvider.realm().commitWrite()
                } catch let error {
                    dump(error)
                    return self.resolve(promise: promise, error: .database(.unknown))
                }
                self.resolve(promise: promise, with: Feed(realmFeed: realmFeed))
            case .failure:
                guard let realmFeed = self.realmProvider.realm().object(ofType: RealmFeed.self,
                                                                        forPrimaryKey: identifier) else {
                    return self.resolve(promise: promise, error: .database(.entryNotFound))
                }
                self.resolve(promise: promise, with: Feed(realmFeed: realmFeed))
            }
        }
    }

    private func upsert(article: Muon.Article, to realmFeed: RealmFeed, feedURL: URL) {
        let realmArticle: RealmArticle
        if let existingArticle = realmFeed.articles.filter(
            "link == %@ OR identifier == %@", article.url?.absoluteString ?? "", article.guid ?? ""
        ).first {
            realmArticle = existingArticle
        } else {
            realmArticle = RealmArticle()
            realmArticle.feed = realmFeed
            self.realmProvider.realm().add(realmArticle)
        }

        let rawTitle: String
        if article.title.isEmpty {
            rawTitle = realmArticle.title ?? "unknown"
        } else {
            rawTitle = article.title
        }
        let title = rawTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        realmArticle.title = title.stringByUnescapingHTML().stringByStrippingHTML()
        realmArticle.link = URL(
            string: article.url?.absoluteString ?? "", relativeTo: feedURL
        )?.absoluteString ?? ""
        realmArticle.published = article.published
        realmArticle.updatedAt = article.updated
        realmArticle.summary = article.summary
        realmArticle.content = article.content
        realmArticle.identifier = article.guid

        article.authors.forEach {
            self.upsert(author: $0, to: realmArticle)
        }
    }

    private func upsert(author: Muon.Author, to article: RealmArticle) {
        let realmAuthor: RealmAuthor
        let predicate = NSPredicate(format: "name == %@", author.name)

        if let existingAuthor = self.realmProvider.realm().objects(RealmAuthor.self).filter(predicate).first {
            realmAuthor = existingAuthor
        } else {
            realmAuthor = RealmAuthor()
            realmAuthor.name = author.name
            self.realmProvider.realm().add(realmAuthor)
        }

        realmAuthor.email = author.email?.absoluteString ?? realmAuthor.email

        if !article.authors.contains(realmAuthor) {
            article.authors.append(realmAuthor)
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
