import Foundation

class FakeDataTask: NSURLSessionDataTask {
    override func resume() {}

    override func cancel() {}
}

class FakeDownloadTask: NSURLSessionDownloadTask {
    var _request: NSURLRequest?
    override var originalRequest: NSURLRequest? {
        return _request
    }

    var _response: NSURLResponse?
    override var response: NSURLResponse? { return _response }

    override func resume() {}

    override func cancel() {}
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

    var lastDownloadTask: NSURLSessionDownloadTask?
    override func downloadTaskWithURL(url: NSURL) -> NSURLSessionDownloadTask {
        lastURL = url
        let task = FakeDownloadTask()
        task._request = NSURLRequest(URL: url)
        lastDownloadTask = task
        downloadTasks.append(task)
        return task
    }

    private var dataTasks = [NSURLSessionDataTask]()
    private var downloadTasks = [NSURLSessionDownloadTask]()

    override func getTasksWithCompletionHandler(completionHandler: ([NSURLSessionDataTask], [NSURLSessionUploadTask], [NSURLSessionDownloadTask]) -> Void) {
        completionHandler(dataTasks, [], downloadTasks)
    }
}
