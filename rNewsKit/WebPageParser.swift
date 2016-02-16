import Kanna

public class WebPageParser: NSOperation {
    private let webPage: String
    private let callback: [NSURL] -> Void

    private var urls = [NSURL]()

    public init(string: String, callback: [NSURL] -> Void) {
        self.webPage = string
        self.callback = callback
        super.init()
    }

    private let acceptableTypes = [
        "application/rss+xml",
        "application/rdf+xml",
        "application/atom+xml",
        "application/xml",
        "text/xml"
    ]

    public override func start() {
        super.start()

        if let doc = Kanna.HTML(html: self.webPage, encoding: NSUTF8StringEncoding) {
            for link in doc.xpath("//link") where link["rel"] == "alternate" &&
                self.acceptableTypes.contains(link["type"] ?? "") {
                    if let urlString = link["href"], url = NSURL(string: urlString) {
                        self.urls.append(url)
                    }
            }
        }
        self.callback(self.urls)
    }
}
