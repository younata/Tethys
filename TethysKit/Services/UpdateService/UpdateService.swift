import Foundation
import CBGPromise
import Result

protocol UpdateService: class {
    func updateFeed(_ feed: Feed) -> Future<Result<Feed, TethysError>>
}
