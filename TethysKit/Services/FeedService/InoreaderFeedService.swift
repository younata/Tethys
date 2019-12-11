import Result
import CBGPromise
import FutureHTTP

struct InoreaderFeedService: FeedService {
    private let httpClient: HTTPClient
    let baseURL: URL

    init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>> {
        let url = self.baseURL.appendingPathComponent("reader/api/0/subscription/list", isDirectory: false)
        let request = URLRequest(url: url)
        return self.httpClient.request(request).map { requestResult -> Result<[InoreaderFeed], NetworkError> in
            switch requestResult {
            case .success(let response):
                return self.parse(response: response).map { (parsed: InoreaderSubscriptions) -> [InoreaderFeed] in
                    return parsed.subscriptions
                }
            case .failure(let clientError):
                return .failure(NetworkError(httpClientError: clientError))
            }
        }.map { feedResult -> Future<Result<[Feed], TethysError>> in
            return feedResult.mapError { return TethysError.network(url, $0) }.mapFuture(self.retrieveFeedDetails)
        }.map { feedResult -> Future<Result<[Feed], TethysError>> in
            return feedResult.mapFuture { feeds in
                return self.requestUnreadCounts().map { unreadCountsResult -> Result<[Feed], TethysError> in
                    return unreadCountsResult.map { unreadCounts in
                        feeds.forEach { feed in
                            feed.unreadCount = unreadCounts[feed.identifier] ?? 0
                        }
                        return feeds
                    }
                }
            }
        }.map { parseResult -> Result<AnyCollection<Feed>, TethysError> in
            return parseResult.map { AnyCollection($0) }
        }
    }

    private func requestUnreadCounts() -> Future<Result<[String: Int], TethysError>> {
        let url = self.baseURL.appendingPathComponent("reader/api/0/unread-count", isDirectory: false)
        let request = URLRequest(url: url)
        return self.httpClient.request(request).map { requestResult -> Result<[String: Int], NetworkError> in
            switch requestResult {
            case .success(let response):
                return self.parse(response: response).map { (parsed: InoreaderUnreadCounts) -> [String: Int] in
                    return parsed.unreadcounts.reduce(
                        into: [String: Int]()
                    ) { (result: inout [String: Int], unreadCount: InoreaderUnreadCount) in
                        result[unreadCount.id] = unreadCount.count
                    }
                }
            case .failure(let clientError):
                return .failure(NetworkError(httpClientError: clientError))
            }
        }.map {
            return $0.mapError { return TethysError.network(url, $0) }
        }
    }

    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        let encodedURL: String = feed.url.absoluteString.addingPercentEncoding(
            withAllowedCharacters: .urlHostAllowed
        ) ?? ""
        let apiUrl = self.baseURL.appendingPathComponent("reader/api/0/stream/contents/feed")
        let url = URL(string: apiUrl.absoluteString + "%2F" + encodedURL)!
        return self.httpClient.request(URLRequest(url: url))
            .map { requestResult -> Result<[InoreaderArticle], NetworkError> in
                switch requestResult {
                case .success(let response):
                    return self.parse(response: response).map { (parsed: InoreaderArticles) -> [InoreaderArticle] in
                        return parsed.items
                    }
                case .failure(let clientError):
                    return .failure(NetworkError(httpClientError: clientError))
                }
        }.map { articlesResult -> Result<AnyCollection<Article>, TethysError> in
            return articlesResult.mapError { return TethysError.network(url, $0) }
                .map { articles -> [Article] in
                    return articles.compactMap {
                        guard let url = $0.canonical.first?.href else { return nil }
                        return Article(
                            title: $0.title,
                            link: url,
                            summary: $0.summary.content,
                            authors: [Author(name: $0.author, email: nil)].filter { $0.name.isEmpty == false },
                            identifier: $0.id,
                            content: $0.summary.content,
                            read: InoreaderTags(tags: $0.categories.map { InoreaderTag(id: $0) }).containsRead,
                            published: $0.published,
                            updated: $0.updated
                        )
                    }
            }.map { AnyCollection($0) }
        }

//        let collection = NetworkPagedCollection<Article>(
//            httpClient: self.httpClient,
//            requestFactory: { (continuationString) -> URLRequest in
//                guard let token = continuationString else {
//                    return URLRequest(url: url)
//                }
//                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
//                components.queryItems = [
//                    URLQueryItem(name: "c", value: token)
//                ]
//                return URLRequest(url: components.url!)
//        },
//            dataParser: { (body: Data) throws -> ([Article], String?) in
//                let decoder = JSONDecoder()
//                decoder.dateDecodingStrategy = .secondsSince1970
//                let parsedArticlesResponse = try decoder.decode(InoreaderArticles.self, from: body)
//                let articles: [Article] = parsedArticlesResponse.items.compactMap {
//                    guard let url = $0.canonical.first?.href else { return nil }
//                    return Article(
//                        title: $0.title,
//                        link: url,
//                        summary: $0.summary.content,
//                        authors: [Author(name: $0.author, email: nil)],
//                        identifier: $0.id,
//                        content: $0.summary.content,
//                        read: InoreaderTags(tags: $0.categories.map { InoreaderTag(id: $0) }).containsRead,
//                        published: $0.published,
//                        updated: $0.updated
//                    )
//                }
//                return (articles, parsedArticlesResponse.continuation)
//        })
//        return Promise<Result<AnyCollection<Article>, TethysError>>.resolved(.success(AnyCollection(collection)))
    }

    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        let apiUrl = self.baseURL.appendingPathComponent("reader/api/0/subscription/quickadd")
        let request: URLRequest
        do {
            let body = try JSONSerialization.data(
                withJSONObject: ["quickadd": "feed/" + url.absoluteString],
                options: []
            )
            request = URLRequest(url: apiUrl, headers: [:], method: .post(body))
        } catch let error {
            print("error creating json data: \(error)")
            return Promise<Result<Feed, TethysError>>.resolved(.failure(TethysError.unknown))
        }
        return self.httpClient.request(request).map { result -> Result<InoreaderSubscribeResponse, NetworkError> in
            switch result {
            case .success(let response):
                return self.parse(response: response)
            case .failure(let clientError):
                return .failure(NetworkError(httpClientError: clientError))
            }
        }.map { result -> Result<Feed, TethysError> in
            switch result {
            case .success(let subscribeResponse):
                let subscribedUrlString = String(subscribeResponse.query.split(
                    separator: "/",
                    maxSplits: 1,
                    omittingEmptySubsequences: true
                )[1])
                let subscribedUrl = URL(string: subscribedUrlString)!
                return .success(Feed(
                    title: subscribeResponse.streamName,
                    url: subscribedUrl,
                    summary: "",
                    tags: []
                ))
            case .failure(let networkError):
                return .failure(.network(apiUrl, networkError))
            }
        }
    }

    func tags() -> Future<Result<AnyCollection<String>, TethysError>> {
        let apiUrl = self.baseURL.appendingPathComponent("reader/api/0/tag/list")
        let request = URLRequest(url: apiUrl)
        return self.httpClient.request(request).map { requestResult -> Result<[String], NetworkError> in
            switch requestResult {
            case .success(let response):
                return self.parse(response: response).map { (parsed: InoreaderTags) -> [String] in
                    return parsed.tags.compactMap { $0.tagName }
                }
            case .failure(let clientError):
                return .failure(NetworkError(httpClientError: clientError))
            }
            }.map { result -> Result<AnyCollection<String>, TethysError> in
                return result.mapError { return TethysError.network(apiUrl, $0) }.map { AnyCollection($0) }
        }
    }

    func set(tags: [String], of feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>.resolved(.failure(.notSupported))
    }

    func set(url: URL, on feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>.resolved(.failure(.notSupported))
    }

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        var urlComponents = URLComponents(url: self.baseURL.appendingPathComponent("reader/api/0/mark-all-as-read"),
                                          resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "s", value: "feed/\(feed.url.absoluteString)")
        ]
        let url = urlComponents.url!
        let request = URLRequest(url: url)
        return self.httpClient.request(request).map { requestResult -> Result<Void, NetworkError> in
            switch requestResult {
            case .success(let response):
                guard response.status == .ok else {
                    guard let receivedStatus = response.status, let status = HTTPError(status: receivedStatus) else {
                        return .failure(.unknown)
                    }
                    return .failure(.http(status, response.body))
                }
                return .success(Void())
            case .failure(let error):
                return .failure(NetworkError(httpClientError: error))
            }
        }.map { result -> Result<Void, TethysError> in
            return result.mapError { return TethysError.network(url, $0) }
        }
    }

    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        var urlComponents = URLComponents(url: self.baseURL.appendingPathComponent("reader/api/0/subscription/edit"),
                                          resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "ac", value: "unsubscribe"),
            URLQueryItem(name: "s", value: "feed/\(feed.url.absoluteString)")
        ]
        let url = urlComponents.url!
        let request = URLRequest(url: url)
        return self.httpClient.request(request).map { requestResult -> Result<Void, NetworkError> in
            switch requestResult {
            case .success(let response):
                guard response.status == .ok else {
                    guard let receivedStatus = response.status, let status = HTTPError(status: receivedStatus) else {
                        return .failure(.unknown)
                    }
                    return .failure(.http(status, response.body))
                }
                return .success(Void())
            case .failure(let error):
                return .failure(NetworkError(httpClientError: error))
            }
        }.map { result -> Result<Void, TethysError> in
            return result.mapError { return TethysError.network(url, $0) }
        }
    }

    // MARK: Private

    private func parse<T: Decodable>(response: HTTPResponse) -> Result<T, NetworkError> {
        guard response.status == .ok else {
            guard let receivedStatus = response.status, let status = HTTPError(status: receivedStatus) else {
                return .failure(.unknown)
            }
            return .failure(.http(status, response.body))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return .success(try decoder.decode(T.self, from: response.body))
        } catch let error {
            print("error decoding data: \(String(describing: String(data: response.body, encoding: .utf8)))")
            dump(error)
            return .failure(.badResponse)
        }
    }

    private func retrieveFeedDetails(feeds: [InoreaderFeed]) -> Future<Result<[Feed], TethysError>> {
        return Promise<Result<[Feed], TethysError>>.resolved(.success(feeds.map {
            return Feed(
                title: $0.title,
                url: $0.url,
                summary: "",
                tags: $0.categories.map { $0.label },
                unreadCount: 0,
                image: nil,
                identifier: $0.id,
                settings: nil
            )
        }))
    }
}

private struct InoreaderSubscriptions: Codable {
    let subscriptions: [InoreaderFeed]
}

private struct InoreaderFeed: Codable {
    let id: String
    let title: String
    let categories: [InoreaderCategory]
    let sortid: String
    let firstitemmsec: Int
    let url: URL
    let htmlUrl: URL
    let iconUrl: String
}

private struct InoreaderCategory: Codable {
    let id: String
    let label: String
}

private struct InoreaderArticles: Codable {
    let id: String
    let title: String
    let updated: Date
    let continuation: String
    let items: [InoreaderArticle]
}

private struct InoreaderArticle: Codable {
    let id: String
    let title: String
    let categories: [String]
    let published: Date
    let updated: Date?
    let canonical: [InoreaderLink]
    let alternate: [InoreaderLink]
    let author: String
    let summary: InoreaderSummary
}

private struct InoreaderLink: Codable {
    let href: URL
    let type: String?
}

private struct InoreaderSummary: Codable {
    let content: String
}

private struct InoreaderSubscribeResponse: Codable {
    let query: String
    let numResults: Int
    let streamId: String
    let streamName: String
}

private struct InoreaderTags: Codable {
    let tags: [InoreaderTag]

    var containsRead: Bool {
        return self.tags.contains(where: { $0.isRead })
    }
}

private struct InoreaderTag: Codable {
    let id: String

    var tagName: String? {
        // user/-/label/Tech, only if "label" in the preceeding.
        let components = self.id.components(separatedBy: "/")
        guard components.count >= 4 else { return nil }
        guard components[2] == "label" else { return nil }
        return components[3..<(components.count)].joined(separator: "/")
    }

    var state: String? {
        let components = self.id.components(separatedBy: "/")
        guard components.count >= 5 else { return nil }
        guard components[2] == "state" else { return nil }
        return components[3..<(components.count)].joined(separator: "/")
    }

    var isRead: Bool {
        return self.state == "com.google/read"
    }
}

private struct InoreaderUnreadCounts: Codable {
    let max: String
    let unreadcounts: [InoreaderUnreadCount]
}

private struct InoreaderUnreadCount: Codable {
    let id: String
    let count: Int
    let newestItemTimestampUsec: String
}
