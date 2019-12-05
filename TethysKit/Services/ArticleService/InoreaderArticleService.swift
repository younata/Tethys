import Result
import CBGPromise
import FutureHTTP

struct InoreaderArticleService: ArticleService {
    let httpClient: HTTPClient
    let baseURL: URL

    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>> {
        var urlComponents = URLComponents(url: self.baseURL.appendingPathComponent("reader/api/0/edit-tag"),
                                          resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: read ? "a" : "r", value: "user/state/com.google/read"),
            URLQueryItem(name: "i", value: article.identifier)
        ]
        let request = URLRequest(url: urlComponents.url!, headers: [:], method: .post(Data()))
        return self.httpClient.request(request).map { requestResult -> Result<Article, NetworkError> in
            switch requestResult {
            case .success(let response):
                guard response.status == .ok else {
                    guard let receivedStatus = response.status, let status = HTTPError(status: receivedStatus) else {
                        return .failure(.unknown)
                    }
                    return .failure(.http(status))
                }
                var writeableArticle = article
                writeableArticle.read = read
                return .success(writeableArticle)
            case .failure(let clientError):
                return .failure(NetworkError(httpClientError: clientError))
            }
        }.map { (articleResult: Result<Article, NetworkError>) -> Result<Article, TethysError> in
            return articleResult.mapError { return TethysError.network(urlComponents.url!, $0) }
        }
    }

    func remove(article: Article) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>.resolved(.failure(.notSupported))
    }

    func authors(of article: Article) -> String {
        return article.authors.map { $0.description }.joined(separator: ", ")
    }

    func date(for article: Article) -> Date {
        let updatedDate = article.updated ?? article.published
        if updatedDate < article.published {
            return article.published
        }
        return updatedDate
    }

    func estimatedReadingTime(of article: Article) -> TimeInterval {
        let htmlString: String
        if article.content.isEmpty == false {
            htmlString = article.content
        } else if article.summary.isEmpty == false {
            htmlString = article.summary
        } else {
            return 0
        }
        let words = htmlString.stringByStrippingHTML().components(separatedBy: " ")

        let wordsPerSecond: TimeInterval = 10.0 / 3.0 // 200 words per minute / 60 seconds per minute
        return TimeInterval(words.count) / wordsPerSecond
    }
}
