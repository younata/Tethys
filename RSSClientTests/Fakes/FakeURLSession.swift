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

    var _taskDescription: String?
    override var taskDescription: String? {
        get {
            return _taskDescription
        }
        set {
            _taskDescription = newValue
        }
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

    var lastDownloadTask: FakeDownloadTask?
    override func downloadTaskWithRequest(request: NSURLRequest) -> NSURLSessionDownloadTask {
        lastURL = request.URL
        let task = FakeDownloadTask()
        task._request = request
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
