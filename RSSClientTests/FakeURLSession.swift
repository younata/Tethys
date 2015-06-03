import UIKit

class FakeDataTask: NSURLSessionDataTask {
    override func resume() {

    }
}

class FakeURLSession: NSURLSession {
    var lastURL: NSURL? = nil
    var lastCompletionHandler: (NSData!, NSURLResponse!, NSError!) -> (Void) = {_, _, _ in }
    override func dataTaskWithURL(url: NSURL, completionHandler: ((NSData!, NSURLResponse!, NSError!) -> Void)?) -> NSURLSessionDataTask {
        lastURL = url
        if let handler = completionHandler {
            lastCompletionHandler = handler
        }
        return FakeDataTask()
    }
}
