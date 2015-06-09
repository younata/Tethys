import Muon

class FeedRepository {

    typealias FeedRepositoryCallback = (Muon.Feed?, NSError?) -> (Void)

    class func loadFeed(url: String, urlSession: NSURLSession,
        operationQueue: NSOperationQueue, callback: FeedRepositoryCallback) {
            operationQueue.addOperationWithBlock {
                guard let url = NSURL(string: url) else {
                    callback(nil, NSError(domain: "", code: 0, userInfo: [:]))
                    return
                }
                urlSession.dataTaskWithURL(url) {data, _, error in
                    if let err = error {
                        callback(nil, err)
                    } else if let data = data, let s = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
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
