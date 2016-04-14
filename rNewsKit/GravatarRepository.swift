import Result
import CBGPromise
import Foundation
import Crypto
import Ra

public enum GravatarRepositoryError: ErrorType, Equatable {
    case Unrecognized
    case Network
    case Unknown
}

public protocol GravatarRepository: class {
    func image(email: String) -> Future<Result<Image, GravatarRepositoryError>>
}

class DefaultGravatarRepository: GravatarRepository, Injectable {
    private let urlSession: NSURLSession

    private var cache: [String: Image] = [:]

    init(urlSession: NSURLSession) {
        self.urlSession = urlSession
    }

    required convenience init(injector: Injector) {
        self.init(urlSession: injector.create(NSURLSession.self)!)
    }

    func image(email: String) -> Future<Result<Image, GravatarRepositoryError>> {
        let promise = Promise<Result<Image, GravatarRepositoryError>>()
        let email = email.lowercaseString
        if let image = self.cache[email] {
            promise.resolve(Result(value: image))
        } else if let md5 = email.MD5, url = NSURL(string: "http://www.gravatar.com/avatar/" + md5) {
            self.urlSession.dataTaskWithURL(url) { data, _, error in
                if let _ = error {
                    promise.resolve(Result(error: .Network))
                    return
                }
                if let data = data, let image = Image(data: data) {
                    self.cache[email] = image
                    promise.resolve(Result(value: image))
                    return
                } else {
                    promise.resolve(Result(error: .Unrecognized))
                }
            }.resume()
        } else {
            promise.resolve(Result(error: .Unknown))
        }
        return promise.future
    }
}
