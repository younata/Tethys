import Foundation

class FakeDataTask: NSURLSessionDataTask {
    override func resume() {

    }

    override func cancel() {

    }
}

class FakeURLSession: NSURLSession {
    var lastURL: NSURL? = nil
    var lastCompletionHandler: (NSData?, NSURLResponse?, NSError?) -> (Void) = {_, _, _ in }
    override func dataTaskWithURL(url: NSURL, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionDataTask {
        lastURL = url
        lastCompletionHandler = completionHandler
        let task = FakeDataTask()
        dataTasks.append(task)
        return task
    }

    private var dataTasks = [NSURLSessionDataTask]()

    override func getTasksWithCompletionHandler(completionHandler: ([NSURLSessionDataTask], [NSURLSessionUploadTask], [NSURLSessionDownloadTask]) -> Void) {
        completionHandler(dataTasks, [], [])
    }
}
