import Ra
import Muon
import Lepton
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

public typealias ImportUseCaseScanCompletion = (ImportUseCaseItem) -> Void
public typealias ImportUseCaseScanDirectoryCompletion = ([ImportUseCaseItem]) -> Void
public typealias ImportUseCaseImport = (Void) -> Void

public protocol ImportUseCase {
    func scanDirectoryForImportables(_ url: URL, callback: @escaping ImportUseCaseScanDirectoryCompletion)
    func scanForImportable(_ url: URL, callback: @escaping ImportUseCaseScanCompletion)
    func importItem(_ url: URL, callback: @escaping ImportUseCaseImport)
}

public final class DefaultImportUseCase: ImportUseCase, Injectable {
    private let urlSession: URLSession
    private let feedRepository: DatabaseUseCase
    private let opmlService: OPMLService
    private let fileManager: FileManager
    private let mainQueue: OperationQueue
    private let analytics: Analytics

    private enum ImportType {
        case feed
        case opml
    }
    fileprivate var knownUrls: [URL: ImportType] = [:]

    public init(urlSession: URLSession,
                feedRepository: DatabaseUseCase,
                opmlService: OPMLService,
                fileManager: FileManager,
                mainQueue: OperationQueue,
                analytics: Analytics) {
        self.urlSession = urlSession
        self.feedRepository = feedRepository
        self.opmlService = opmlService
        self.fileManager = fileManager
        self.mainQueue = mainQueue
        self.analytics = analytics
    }

    public required convenience init(injector: Injector) {
        self.init(
            urlSession: injector.create(kind: URLSession.self)!,
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            opmlService: injector.create(kind: OPMLService.self)!,
            fileManager: injector.create(kind: FileManager.self)!,
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue,
            analytics: injector.create(kind: Analytics.self)!
        )
    }

    public func scanDirectoryForImportables(_ url: URL, callback: @escaping ImportUseCaseScanDirectoryCompletion) {
        let path = url.path

        let contents = ((try? self.fileManager.contentsOfDirectory(atPath: path)) ?? []).flatMap {
            return URL(string: $0, relativeTo: url)?.absoluteURL
        }

        var ret: [ImportUseCaseItem] = []

        var scanCount = 0

        for url in contents {
            self.scanForImportable(url) {
                switch $0 {
                case .opml(_): ret.append($0)
                case .feed(_): ret.append($0)
                default: break
                }
                scanCount += 1
                if scanCount == contents.count {
                    callback(ret)
                }
            }
        }
    }

    public func scanForImportable(_ url: URL, callback: @escaping ImportUseCaseScanCompletion) {
        if url.isFileURL {
            guard !url.absoluteString.contains("default.realm"), let data = try? Data(contentsOf: url) else {
                callback(.none(url))
                return
            }
            callback(self.scanDataForItem(data, url: url))
        } else {
            self.urlSession.dataTask(with: url) { data, _, error in
                guard error == nil, let data = data else {
                    callback(.none(url))
                    return
                }
                self.mainQueue.addOperation {
                    callback(self.scanDataForItem(data, url: url))
                }
            }.resume()
        }
    }

    public func importItem(_ url: URL, callback: @escaping ImportUseCaseImport) {
        guard let importType = self.knownUrls[url] else { callback(); return }
        switch importType {
        case .feed:
            let url = self.canonicalURLForFeedAtURL(url)
            _ = self.feedRepository.feeds().then {
                guard case let Result.success(feeds) = $0 else { return }
                let existingFeed = feeds.objectPassingTest({ $0.url == url })
                guard existingFeed == nil else {
                    return callback()
                }
                var feed: Feed?
                _ = self.feedRepository.newFeed {
                    $0.url = url
                    feed = $0
                }.then { _ in
                    self.feedRepository.updateFeed(feed!) { _ in callback() }
                }
            }
        case .opml:
            self.opmlService.importOPML(url) { _ in callback() }
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
