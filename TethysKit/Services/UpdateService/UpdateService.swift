import Foundation
import Muon
import CBGPromise
import Result

protocol UpdateService: class {
    func updateFeed(_ feed: TethysKit.Feed) -> Future<Result<TethysKit.Feed, TethysError>>
}
