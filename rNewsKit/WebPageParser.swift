import Kanna

public final class WebPageParser: Operation {
    public enum SearchType {
        case feeds
        case links
        case `default`

        var acceptableTypes: [String] {
            switch self {
            case .feeds:
                return [
                    "application/rss+xml",
                    "application/rdf+xml",
                    "application/atom+xml",
                    "application/xml",
                    "text/xml"
                ]
            case .links, .default:
                return []
            }
        }
    }

    private let webPage: String
    private let callback: ([URL]) -> Void

    private var urls = [URL]()

    public var searchType: SearchType = .default

    public init(string: String, callback: @escaping ([URL]) -> Void) {
        self.webPage = string
        self.callback = callback
        super.init()
    }

    public override func start() {
        super.start()

        if let doc = Kanna.HTML(html: self.webPage, encoding: String.Encoding.utf8) {
            switch self.searchType {
            case .feeds:
                for link in doc.xpath("//link") where link["rel"] == "alternate" &&
                    self.searchType.acceptableTypes.contains(link["type"] ?? "") {
                        if let urlString = link["href"], let url = URL(string: urlString) {
                            self.urls.append(url as URL)
                        }
                }
            case .links:
                for link in doc.xpath("//a") {
                    if let urlString = link["href"], let url = URL(string: urlString) {
                        self.urls.append(url as URL)
                    }
                }
            default:
                break
            }
        }
        self.callback(self.urls)
    }
}
