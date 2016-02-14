import Foundation

public class WebPageParser: NSOperation {
    private let webPage: String
    private let callback: [NSURL] -> Void

    private var parser: NSXMLParser?
    private var urls = [NSURL]()

    public init(string: String, callback: [NSURL] -> Void) {
        self.webPage = string
        self.callback = callback
        super.init()
    }

    public override func start() {
        super.start()

        let parser = NSXMLParser(data: webPage.dataUsingEncoding(NSUTF8StringEncoding)!)
        parser.delegate = self
        parser.parse()
        self.parser = parser
    }

    public override func cancel() {
        super.cancel()

        self.parser?.abortParsing()
    }
}

extension WebPageParser: NSXMLParserDelegate {
    public func parserDidEndDocument(parser: NSXMLParser) {
        self.callback(self.urls)
    }

    public func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        self.callback(self.urls)
        self.cancel()
    }

    public func parser(parser: NSXMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String]) {
            let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
            guard elementName.stringByTrimmingCharactersInSet(characterSet).lowercaseString == "link" else { return }
            if attributeDict["type"] == "application/rss+xml",
                let urlString = attributeDict["href"],
                let url = NSURL(string: urlString) {
                    self.urls.append(url)
            }
    }
}
