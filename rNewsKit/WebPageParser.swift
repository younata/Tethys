import Kanna

public class WebPageParser: NSOperation {
    public enum SearchType {
        case Feeds
        case Links
        case Default

        var acceptableTypes: [String] {
            switch self {
            case .Feeds:
                return [
                    "application/rss+xml",
                    "application/rdf+xml",
                    "application/atom+xml",
                    "application/xml",
                    "text/xml"
                ]
            case .Links, .Default:
                return []
            }
        }
    }

    private let webPage: String
    private let callback: [NSURL] -> Void

    private var urls = [NSURL]()

    public var searchType: SearchType = .Default

    public init(string: String, callback: [NSURL] -> Void) {
        self.webPage = string
        self.callback = callback
        super.init()
    }

    public override func start() {
        super.start()

        if let doc = Kanna.HTML(html: self.webPage, encoding: NSUTF8StringEncoding) {
            switch self.searchType {
            case .Feeds:
                for link in doc.xpath("//link") where link["rel"] == "alternate" &&
                    self.searchType.acceptableTypes.contains(link["type"] ?? "") {
                        if let urlString = link["href"], url = NSURL(string: urlString) {
                            self.urls.append(url)
                        }
                }
            case .Links:
                for link in doc.xpath("//a") {
                    if let urlString = link["href"], url = NSURL(string: urlString) {
                        self.urls.append(url)
                    }
                }
            default:
                break
            }
        }
        self.callback(self.urls)
    }
}
