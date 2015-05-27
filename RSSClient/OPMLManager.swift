import Foundation

class OPMLManager {

    private let dataManager : DataManager

    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }

    func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {

    }

    private func generateOPMLContents(feeds: [Feed]) -> String {
        func sanitize(str: String?) -> String {
            if str == nil {
                return ""
            }
            var s = str!
            s = s.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            s = s.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
            s = s.stringByReplacingOccurrencesOfString("<", withString: "&gt;")
            s = s.stringByReplacingOccurrencesOfString(">", withString: "&lt;")
            s = s.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            return s
        }

        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
        ret += "<opml version=\"2.0\">\n    <body>\n"
        for feed in feeds.filter({return $0.query == nil}) {
            let title = "title=\"\(sanitize(feed.title))\""
            let url = "xmlUrl=\"\(sanitize(feed.url?.absoluteString))\""
            let tags: String
            if feed.tags.count != 0 {
                let tagsList: String = ",".join(feed.tags)
                tags = "tags=\"\(tagsList)\""
            } else {
                tags = ""
            }
            var line = "<outline \(url) \(title) \(tags) type=\"rss\"/>"
            ret += "        \(line)\n"
        }
        ret += "    </body>\n</opml>"
        return ret
    }

    func writeOPML() {
        let opmlLocation = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
        self.generateOPMLContents(dataManager.feeds()).writeToFile(opmlLocation, atomically: true,
            encoding: NSUTF8StringEncoding, error: nil)
    }
}