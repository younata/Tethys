import Result
import CBGPromise
import FutureHTTP

struct InoreaderFeedService: FeedService {
    private let httpClient: HTTPClient
    private let baseURL: URL

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
                return self.parseSubscriptionList(response: response)
            case .failure(let clientError):
                return .failure(NetworkError(httpClientError: clientError))
            }
        }.map { feedResult -> Future<Result<[Feed], TethysError>> in
            return feedResult.mapError { return TethysError.network(url, $0) }.mapFuture(self.retrieveArticleDetails)
        }.map { parseResult -> Result<AnyCollection<Feed>, TethysError> in
            return parseResult.map { AnyCollection($0) }
        }
    }

    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        return Promise<Result<AnyCollection<Article>, TethysError>>().future
    }

    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    func tags() -> Future<Result<AnyCollection<String>, TethysError>> {
        return Promise<Result<AnyCollection<String>, TethysError>>().future
    }

    func set(tags: [String], of feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    func set(url: URL, on feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>().future
    }

    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>().future
    }

    // MARK: Private

    private func parseSubscriptionList(response: HTTPResponse) -> Result<[InoreaderFeed], NetworkError> {
        guard response.status == .ok else {
            guard let receivedStatus = response.status, let status = HTTPError(status: receivedStatus) else {
                return .failure(.unknown)
            }
            return .failure(.http(status))
        }

        let decoder = JSONDecoder()
        let feeds: [InoreaderFeed]
        do {
            feeds = try decoder.decode(InoreaderSubscriptionResponse.self, from: response.body).subscriptions
        } catch let error {
            print("error decoding data: \(String(describing: String(data: response.body, encoding: .utf8)))")
            dump(error)
            return .failure(.badResponse)
        }
        return .success(feeds)
    }

    private func retrieveArticleDetails(feeds: [InoreaderFeed]) -> Future<Result<[Feed], TethysError>> {
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

private struct InoreaderSubscriptionResponse: Codable {
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
