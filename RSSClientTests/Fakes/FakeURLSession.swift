import Foundation

class FakeDataTask: URLSessionDataTask {
    override func resume() {}

    override func cancel() {}
}

class FakeDownloadTask: URLSessionDownloadTask {
    var _request: URLRequest?
    override var originalRequest: URLRequest? {
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

    var _response: URLResponse?
    override var response: URLResponse? { return _response }

    override func resume() {}

    override func cancel() {}
}

class FakeURLSession: URLSession {
    var lastURL: URL? = nil
    var lastCompletionHandler: (Data?, URLResponse?, NSError?) -> (Void) = {_, _, _ in }
    override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        lastURL = url
        lastCompletionHandler = completionHandler
        let task = FakeDataTask()
        dataTasks.append(task)
        return task
    }

    var lastDownloadTask: FakeDownloadTask?
    override func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        lastURL = request.url
        let task = FakeDownloadTask()
        task._request = request
        lastDownloadTask = task
        downloadTasks.append(task)
        return task
    }

    fileprivate var dataTasks = [URLSessionDataTask]()
    fileprivate var downloadTasks = [URLSessionDownloadTask]()

    override func getTasksWithCompletionHandler(_ completionHandler: @escaping  ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask]) -> Void) {
        completionHandler(dataTasks, [], downloadTasks)
    }
}
