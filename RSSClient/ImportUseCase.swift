import Ra
import Muon
import Lepton
import rNewsKit

public enum ImportUseCaseItem {
    case None(NSURL)
    case WebPage(NSURL, [NSURL])
    case Feed(NSURL)
    case OPML(NSURL)
}

extension ImportUseCaseItem: Equatable {}

public func == (lhs: ImportUseCaseItem, rhs: ImportUseCaseItem) -> Bool {
    switch (lhs, rhs) {
    case (.None(let lhsUrl), .None(let rhsUrl)):
        return lhsUrl == rhsUrl
    case (.WebPage(let lhsUrl, let lhsFeeds), .WebPage(let rhsUrl, let rhsFeeds)):
        return lhsUrl == rhsUrl && lhsFeeds == rhsFeeds
    case (.Feed(let lhsUrl), .Feed(let rhsUrl)):
        return lhsUrl == rhsUrl
    case (.OPML(let lhsUrl), .OPML(let rhsUrl)):
        return lhsUrl == rhsUrl
    default:
        return false
    }
}

public typealias ImportUseCaseScanCompletion = ImportUseCaseItem -> Void
public typealias ImportUseCaseImport = Void -> Void

public protocol ImportUseCase {
    func scanForImportable(url: NSURL, callback: ImportUseCaseScanCompletion)
    func importItem(url: NSURL, callback: ImportUseCaseImport)
}

public final class DefaultImportUseCase: ImportUseCase, Injectable {
    private let urlSession: NSURLSession
    private let feedRepository: FeedRepository
    private let opmlService: OPMLService
    private enum ImportType {
        case Feed
        case OPML
    }
    private var knownUrls: [NSURL: ImportType] = [:]

    public init(urlSession: NSURLSession,
                feedRepository: FeedRepository,
                opmlService: OPMLService) {
        self.urlSession = urlSession
        self.feedRepository = feedRepository
        self.opmlService = opmlService
    }

    public required convenience init(injector: Injector) {
        self.init(
            urlSession: injector.create(NSURLSession)!,
            feedRepository: injector.create(FeedRepository)!,
            opmlService: injector.create(OPMLService)!
        )
    }

    public func scanForImportable(url: NSURL, callback: ImportUseCaseScanCompletion) {
        self.urlSession.dataTaskWithURL(url) { data, _, error in
            guard error == nil, let data = data, string = String(data: data, encoding: NSUTF8StringEncoding) else {
                callback(.None(url))
                return
            }
            if self.isDataAFeed(string) {
                self.knownUrls[url] = .Feed
                callback(.Feed(url))
            } else if self.isDataAnOPML(string) {
                self.knownUrls[url] = .OPML
                callback(.OPML(url))
            } else {
                let feedUrls = self.feedsInWebPage(url, webPage: string)
                feedUrls.forEach { self.knownUrls[$0] = .Feed }
                callback(.WebPage(url, feedUrls))
            }
        }
    }

    public func importItem(url: NSURL, callback: ImportUseCaseImport) {
        guard let importType = self.knownUrls[url] else { callback(); return }
        switch importType {
        case .Feed:
            self.feedRepository.newFeed {
                $0.url = url
                self.feedRepository.updateFeed($0) { _ in callback() }
            }
        case .OPML:
            self.opmlService.importOPML(url) { _ in callback() }
        }
    }
}

// MARK: private

extension DefaultImportUseCase {
    private func isDataAFeed(data: String) -> Bool {
        var ret = false
        let feedParser = FeedParser(string: data)
        feedParser.success { _ in
            ret = true
        }
        feedParser.start()
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
        webPageParser.start()
        return ret
    }
}
