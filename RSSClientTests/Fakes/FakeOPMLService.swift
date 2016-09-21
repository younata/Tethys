import Foundation
@testable import rNewsKit
import Ra
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
    var writeOPMLPromises: [Promise<Result<URL, RNewsError>>] = []
    func writeOPML() -> Future<Result<URL, RNewsError>> {
        didReceiveWriteOPML = true
        let promise = Promise<Result<URL, RNewsError>>()
        writeOPMLPromises.append(promise)
        return promise.future
    }
}
