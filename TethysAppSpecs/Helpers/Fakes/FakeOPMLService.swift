import Foundation
@testable import TethysKit
import CBGPromise
import Result

class FakeOPMLService: OPMLService {
    var importOPMLCalls: [URL] = []
    var importOPMLPromises: [Promise<Result<AnyCollection<Feed>, TethysError>>] = []
    var importOPMLCompletion : ([Feed]) -> Void = {_ in }
    func importOPML(_ opml: URL) -> Future<Result<AnyCollection<Feed>, TethysError>> {
        self.importOPMLCalls.append(opml)
        let promise = Promise<Result<AnyCollection<Feed>, TethysError>>()
        self.importOPMLPromises.append(promise)
        return promise.future
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
