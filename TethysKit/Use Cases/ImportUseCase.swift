import Muon
import Lepton
import Result
import CBGPromise
import FutureHTTP

public enum ImportUseCaseItem: Equatable {
    case none(URL)
    case webPage(URL, [URL])
    case feed(URL, Int)
    case opml(URL, Int)
}

public protocol ImportUseCase {
    func scanForImportable(_ url: URL) -> Future<ImportUseCaseItem>
    func importItem(_ url: URL) -> Future<Result<Void, TethysError>>
}

public final class DefaultImportUseCase: ImportUseCase {
    private let httpClient: HTTPClient
    private let feedService: FeedService
    private let opmlService: OPMLService
    private let fileManager: FileManager
    private let mainQueue: OperationQueue

    fileprivate enum ImportType {
        case feed
        case opml
    }
    fileprivate var knownUrls: [URL: ImportType] = [:]

    public init(httpClient: HTTPClient,
                feedService: FeedService,
                opmlService: OPMLService,
                fileManager: FileManager,
                mainQueue: OperationQueue) {
        self.httpClient = httpClient
        self.feedService = feedService
        self.opmlService = opmlService
        self.fileManager = fileManager
        self.mainQueue = mainQueue
    }

    public func scanForImportable(_ url: URL) -> Future<ImportUseCaseItem> {
        let promise = Promise<ImportUseCaseItem>()
        if url.isFileURL {
            guard !url.absoluteString.contains("default.realm"), let data = try? Data(contentsOf: url) else {
                promise.resolve(.none(url))
                return promise.future
            }
            promise.resolve(self.scanDataForItem(data, url: url))
        } else {
            self.httpClient.request(URLRequest(url: url)).map { result in
                switch result {
                case .success(let response):
                    self.mainQueue.addOperation {
                        promise.resolve(self.scanDataForItem(response.body, url: url))
                    }
                case .failure:
                    self.mainQueue.addOperation {
                        promise.resolve(.none(url))
                    }
                }
            }
        }
        return promise.future
    }

    public func importItem(_ url: URL) -> Future<Result<Void, TethysError>> {
        guard let importType = self.knownUrls[url] else {
            let promise = Promise<Result<Void, TethysError>>()
            promise.resolve(.failure(.unknown))
            return promise.future
        }
        switch importType {
        case .feed:
            let url = self.canonicalURLForFeedAtURL(url)
            return self.feedService.subscribe(to: url).map { result in
                return result.map { _ in Void() }
            }
        case .opml:
            return self.opmlService.importOPML(url).map { result in
                return result.map { _ in Void() }
            }
        }
    }

    private func scanDataForItem(_ data: Data, url: URL) -> ImportUseCaseItem {
        guard let string = String(data: data, encoding: String.Encoding.utf8) else {
            return .none(url)
        }
        if let feedCount = self.isDataAFeed(string) {
            self.knownUrls[url] = .feed
            return .feed(url, feedCount)
        } else if let opmlCount = self.isDataAnOPML(string) {
            self.knownUrls[url] = .opml
            return .opml(url, opmlCount)
        } else {
            let feedUrls = self.feedsInWebPage(url, webPage: string)
            feedUrls.forEach { self.knownUrls[$0] = .feed }
            return .webPage(url, feedUrls)
        }
    }

    private func isDataAFeed(_ data: String) -> Int? {
        var ret: Int?
        let feedParser = FeedParser(string: data)
        _ = feedParser.success {
            ret = $0.articles.count
        }
        feedParser.start()
        return ret
    }

    private func canonicalURLForFeedAtURL(_ url: URL) -> URL {
        guard url.isFileURL else { return url }
        let string = (try? String(contentsOf: url)) ?? ""
        var ret: URL! = nil
        FeedParser(string: string).success {
            ret = $0.link
        }.start()
        return ret
    }

    private func isDataAnOPML(_ data: String) -> Int? {
        var ret: Int?
        let opmlParser = Parser(text: data)
        _ = opmlParser.success {
            ret = $0.count
        }
        opmlParser.start()
        return ret
    }

    private func feedsInWebPage(_ url: URL, webPage: String) -> [URL] {
        var ret: [URL] = []
        let webPageParser = WebPageParser(string: webPage) {
            ret = $0.map { URL(string: $0.absoluteString, relativeTo: url)?.absoluteURL ?? $0 as URL }
        }
        webPageParser.searchType = .feeds
        webPageParser.start()
        return ret
    }
}
