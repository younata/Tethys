import Foundation
import rNews

class DataManagerMock : DataManager {
    var importOPMLURL : NSURL? = nil
    var importOPMLProgress : (Double) -> Void = {_ in }
    var importOPMLCompletion : ([Feed]) -> Void = {_ in }
    override func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
        importOPMLURL = opml
        importOPMLProgress = progress
        importOPMLCompletion = completion
    }

    var newFeedURL: String? = nil
    var newFeedCompletion : (NSError?) -> Void = {_ in }
    override func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        newFeedURL = feedURL
        newFeedCompletion = completion
        return Feed(title: "", url: NSURL(string: feedURL), summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
    }

    override func newQueryFeed(title: String, code: String, summary: String?) -> Feed {
        return Feed(title: title, url: nil, summary: summary ?? "", query: code, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
    }

    var feedsList : [Feed] = []
    override func feeds() -> [Feed] {
        return feedsList
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: (NSError?) -> (Void) = {_ in }
    override func updateFeeds(completion: (NSError?) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = completion
    }

    override func updateFeedsInBackground(completion: (NSError?) -> (Void)) {
        completion(nil)
    }

    override func updateFeeds(feeds: [Feed], backgroundFetch: Bool, completion: (NSError?)->(Void)) {
        completion(nil)
    }
}