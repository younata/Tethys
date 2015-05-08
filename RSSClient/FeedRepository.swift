import Alamofire
import Muon

class FeedRepository {

    typealias FeedRepositoryCallback = (Muon.Feed?, NSError?) -> (Void)

    class func loadFeed(url: String, downloadManager: Alamofire.Manager, operationQueue: NSOperationQueue, callback: FeedRepositoryCallback) {
        operationQueue.addOperationWithBlock {
            downloadManager.request(.GET, url).responseString {(req, response, str, error) in
                if let err = error {
                    callback(nil, err)
                } else if let s = str {
                    let feedParser = Muon.FeedParser(string: s)
                    feedParser.success { callback($0, nil) }.failure { callback(nil, $0) }
                    operationQueue.addOperation(feedParser)
                } else {
                    callback(nil, nil)
                }
            }
        }
    }
}
