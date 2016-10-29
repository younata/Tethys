import Ra
import Muon
import Lepton
import CBGPromise
import Result

public enum ImportUseCaseItem {
    case none(URL)
    case webPage(URL, [URL])
    case feed(URL, Int)
    case opml(URL, Int)
}

extension ImportUseCaseItem: Equatable {}

public func == (lhs: ImportUseCaseItem, rhs: ImportUseCaseItem) -> Bool {
    switch (lhs, rhs) {
    case (.none(let lhsUrl), .none(let rhsUrl)):
        return lhsUrl == rhsUrl
    case (.webPage(let lhsUrl, let lhsFeeds), .webPage(let rhsUrl, let rhsFeeds)):
        return lhsUrl == rhsUrl && lhsFeeds == rhsFeeds
    case (.feed(let lhsUrl, _), .feed(let rhsUrl, _)):
        return lhsUrl == rhsUrl
    case (.opml(let lhsUrl, _), .opml(let rhsUrl, _)):
        return lhsUrl == rhsUrl
    default:
        return false
    }
}

public protocol ImportUseCase {
    func scanForImportable(_ url: URL) -> Future<ImportUseCaseItem>
    func importItem(_ url: URL) -> Future<Result<Void, RNewsError>>
}

public final class DefaultImportUseCase: ImportUseCase, Injectable {
    private let urlSession: URLSession
    private let feedRepository: DatabaseUseCase
    private let opmlService: OPMLService
    private let fileManager: FileManager
    private let mainQueue: OperationQueue

    private enum ImportType {
        case feed
        case opml
    }
    fileprivate var knownUrls: [URL: ImportType] = [:]

    public init(urlSession: URLSession,
                feedRepository: DatabaseUseCase,
                opmlService: OPMLService,
                fileManager: FileManager,
                mainQueue: OperationQueue) {
        self.urlSession = urlSession
        self.feedRepository = feedRepository
        self.opmlService = opmlService
        self.fileManager = fileManager
        self.mainQueue = mainQueue
    }

    public required convenience init(injector: Injector) {
        self.init(
            urlSession: injector.create(kind: URLSession.self)!,
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            opmlService: injector.create(kind: OPMLService.self)!,
            fileManager: injector.create(kind: FileManager.self)!,
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue
        )
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
            self.urlSession.dataTask(with: url) { data, _, error in
                guard error == nil, let data = data else {
                    promise.resolve(.none(url))
                    return
                }
                self.mainQueue.addOperation {
                    promise.resolve(self.scanDataForItem(data, url: url))
                }
            }.resume()
        }
        return promise.future
    }

    public func importItem(_ url: URL) -> Future<Result<Void, RNewsError>> {
        guard let importType = self.knownUrls[url] else {
            let promise = Promise<Result<Void, RNewsError>>()
            promise.resolve(.failure(.unknown))
            return promise.future
        }
        switch importType {
        case .feed:
            let url = self.canonicalURLForFeedAtURL(url)
            return self.feedRepository.feeds().map { result -> Future<Result<Void, RNewsError>> in
                let promise = Promise<Result<Void, RNewsError>>()
                switch result {
                case let .success(feeds):
                    let existingFeed = feeds.objectPassingTest({ $0.url == url })
                    guard existingFeed == nil else {
                        promise.resolve(.failure(.unknown))
                        return promise.future
                    }
                    var feed: Feed?
                    _ = self.feedRepository.newFeed(url: url) {
                        feed = $0
                    }.then { _ in
                        self.feedRepository.updateFeed(feed!) { _ in
                            guard promise.future.value == nil else { return }
                            promise.resolve(.success())
                        }
                    }
                case let .failure(error):
                    promise.resolve(.failure(error))
                }
                return promise.future
            }
        case .opml:
            let promise = Promise<Result<Void, RNewsError>>()
            self.opmlService.importOPML(url) { _ in promise.resolve(.success()) }
            return promise.future
        }
    }
}

// MARK: private

extension DefaultImportUseCase {
    fileprivate func scanDataForItem(_ data: Data, url: URL) -> ImportUseCaseItem {
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

    fileprivate func isDataAFeed(_ data: String) -> Int? {
        var ret: Int? = nil
        let feedParser = FeedParser(string: data)
        _ = feedParser.success {
            ret = $0.articles.count
        }
        feedParser.start()
        return ret
    }

    fileprivate func canonicalURLForFeedAtURL(_ url: URL) -> URL {
        guard url.isFileURL else { return url }
        let string = (try? String(contentsOf: url)) ?? ""
        var ret: URL! = nil
        FeedParser(string: string).success {
            ret = $0.link
        }.start()
        return ret
    }

    fileprivate func isDataAnOPML(_ data: String) -> Int? {
        var ret: Int? = nil
        let opmlParser = Parser(text: data)
        _ = opmlParser.success {
            ret = $0.count
        }
        opmlParser.start()
        return ret
    }

    fileprivate func feedsInWebPage(_ url: URL, webPage: String) -> [URL] {
        var ret: [URL] = []
        let webPageParser = WebPageParser(string: webPage) {
            ret = $0.map { URL(string: $0.absoluteString, relativeTo: url)?.absoluteURL ?? $0 as URL }
        }
        webPageParser.searchType = .feeds
        webPageParser.start()
        return ret
    }
}
