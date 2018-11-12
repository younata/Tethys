import Foundation
@testable import TethysKit
import CBGPromise
import Result

class FakeOPMLService: OPMLService {
    var importOPMLURL : URL? = nil
    var importOPMLCompletion : ([Feed]) -> Void = {_ in }
    func importOPML(_ opml: URL, completion: @escaping ([Feed]) -> Void) {
        importOPMLURL = opml
        importOPMLCompletion = completion
    }

    var didReceiveWriteOPML = false
    var writeOPMLPromises: [Promise<Result<URL, TethysError>>] = []
    func writeOPML() -> Future<Result<URL, TethysError>> {
        didReceiveWriteOPML = true
        let promise = Promise<Result<URL, TethysError>>()
        writeOPMLPromises.append(promise)
        return promise.future
    }
}
