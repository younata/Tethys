import Ra
import Muon
import Lepton
import Result

public enum ImportUseCaseItem {
    case None(NSURL)
    case WebPage(NSURL, [NSURL])
    case Feed(NSURL, Int)
    case OPML(NSURL, Int)
}

extension ImportUseCaseItem: Equatable {}

public func == (lhs: ImportUseCaseItem, rhs: ImportUseCaseItem) -> Bool {
    switch (lhs, rhs) {
    case (.None(let lhsUrl), .None(let rhsUrl)):
        return lhsUrl == rhsUrl
    case (.WebPage(let lhsUrl, let lhsFeeds), .WebPage(let rhsUrl, let rhsFeeds)):
        return lhsUrl == rhsUrl && lhsFeeds == rhsFeeds
    case (.Feed(let lhsUrl, _), .Feed(let rhsUrl, _)):
        return lhsUrl == rhsUrl
    case (.OPML(let lhsUrl, _), .OPML(let rhsUrl, _)):
        return lhsUrl == rhsUrl
    default:
        return false
    }
}

public typealias ImportUseCaseScanCompletion = ImportUseCaseItem -> Void
public typealias ImportUseCaseScanDirectoryCompletion = [ImportUseCaseItem] -> Void
public typealias ImportUseCaseImport = Void -> Void

public protocol ImportUseCase {
    func scanDirectoryForImportables(url: NSURL, callback: ImportUseCaseScanDirectoryCompletion)
    func scanForImportable(url: NSURL, callback: ImportUseCaseScanCompletion)
    func importItem(url: NSURL, callback: ImportUseCaseImport)
}

public final class DefaultImportUseCase: ImportUseCase, Injectable {
    private let urlSession: NSURLSession
    private let feedRepository: DatabaseUseCase
    private let opmlService: OPMLService
    private let fileManager: NSFileManager
    private let mainQueue: NSOperationQueue

    private enum ImportType {
        case Feed
        case OPML
    }
    private var knownUrls: [NSURL: ImportType] = [:]

    public init(urlSession: NSURLSession,
                feedRepository: DatabaseUseCase,
                opmlService: OPMLService,
                fileManager: NSFileManager,
                mainQueue: NSOperationQueue) {
        self.urlSession = urlSession
        self.feedRepository = feedRepository
        self.opmlService = opmlService
        self.fileManager = fileManager
        self.mainQueue = mainQueue
    }

    public required convenience init(injector: Injector) {
        self.init(
            urlSession: injector.create(NSURLSession)!,
            feedRepository: injector.create(DatabaseUseCase)!,
            opmlService: injector.create(OPMLService)!,
            fileManager: injector.create(NSFileManager)!,
            mainQueue: injector.create(kMainQueue) as! NSOperationQueue
        )
    }

    public func scanDirectoryForImportables(url: NSURL, callback: ImportUseCaseScanDirectoryCompletion) {
        guard let path = url.path else { callback([]); return }

        let contents = ((try? self.fileManager.contentsOfDirectoryAtPath(path)) ?? []).flatMap {
            return NSURL(string: $0, relativeToURL: url)?.absoluteURL
        }

        var ret: [ImportUseCaseItem] = []

        var scanCount = 0

        for url in contents {
            self.scanForImportable(url) {
                switch $0 {
                case .OPML(_): ret.append($0)
                case .Feed(_): ret.append($0)
                default: break
                }
                scanCount += 1
                if scanCount == ret.count {
                    callback(ret)
                }
            }
        }
    }

    public func scanForImportable(url: NSURL, callback: ImportUseCaseScanCompletion) {
        if url.fileURL {
            guard let data = NSData(contentsOfURL: url) else {
                callback(.None(url))
                return
            }
            callback(self.scanDataForItem(data, url: url))
        } else {
            self.urlSession.dataTaskWithURL(url) { data, _, error in
                guard error == nil, let data = data else {
                    callback(.None(url))
                    return
                }
                self.mainQueue.addOperationWithBlock {
                    callback(self.scanDataForItem(data, url: url))
                }
            }.resume()
        }
    }

    public func importItem(url: NSURL, callback: ImportUseCaseImport) {
        guard let importType = self.knownUrls[url] else { callback(); return }
        switch importType {
        case .Feed:
            let url = self.canonicalURLForFeedAtURL(url)
            self.feedRepository.feeds().then {
                guard case let Result.Success(feeds) = $0 else { return }
                let existingFeed = feeds.filter({ $0.url == url }).first
                guard existingFeed == nil else {
                    return callback()
                }
                self.feedRepository.newFeed {
                    $0.url = url
                    self.feedRepository.updateFeed($0) { _ in callback() }
                }
            }
        case .OPML:
            self.opmlService.importOPML(url) { _ in callback() }
        }
    }
}

// MARK: private

extension DefaultImportUseCase {
    private func scanDataForItem(data: NSData, url: NSURL) -> ImportUseCaseItem {
        guard let string = String(data: data, encoding: NSUTF8StringEncoding) else {
            return .None(url)
        }
        if self.isDataAFeed(string) {
            self.knownUrls[url] = .Feed
            return .Feed(url, 0)
        } else if self.isDataAnOPML(string) {
            self.knownUrls[url] = .OPML
            return .OPML(url, 0)
        } else {
            let feedUrls = self.feedsInWebPage(url, webPage: string)
            feedUrls.forEach { self.knownUrls[$0] = .Feed }
            return .WebPage(url, feedUrls)
        }
    }

    private func isDataAFeed(data: String) -> Bool {
        var ret = false
        let feedParser = FeedParser(string: data)
        feedParser.success { _ in
            ret = true
        }
        feedParser.start()
        return ret
    }

    private func canonicalURLForFeedAtURL(url: NSURL) -> NSURL {
        guard url.fileURL else { return url }
        let string = (try? String(contentsOfURL: url)) ?? ""
        var ret: NSURL! = nil
        FeedParser(string: string).success {
            ret = $0.link
        }.start()
        return ret
    }

    private func isDataAnOPML(data: String) -> Bool {
        var ret = false
        let opmlParser = Parser(text: data)
        opmlParser.success { _ in
            ret = true
        }
        opmlParser.start()
        return ret
    }

    private func feedsInWebPage(url: NSURL, webPage: String) -> [NSURL] {
        var ret: [NSURL] = []
        let webPageParser = WebPageParser(string: webPage) {
            ret = $0.map { NSURL(string: $0.absoluteString, relativeToURL: url)?.absoluteURL ?? $0 }
        }
        webPageParser.searchType = .Feeds
        webPageParser.start()
        return ret
    }
}
