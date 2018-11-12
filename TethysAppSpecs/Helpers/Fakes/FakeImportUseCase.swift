import Tethys
import TethysKit
import CBGPromise
import Result

class FakeImportUseCase : ImportUseCase {
    init() {}

    private(set) var scanForImportableCalls: [URL] = []
    private(set) var scanForImportablePromises: [Promise<ImportUseCaseItem>] = []
    func scanForImportable(_ url: URL) -> Future<ImportUseCaseItem> {
        self.scanForImportableCalls.append((url))
        let promise = Promise<ImportUseCaseItem>()
        self.scanForImportablePromises.append(promise)
        return promise.future
    }

    private(set) var importItemCalls: [URL] = []
    private(set) var importItemPromises: [Promise<Result<Void, TethysError>>] = []
    func importItem(_ url: URL) -> Future<Result<Void, TethysError>> {
        self.importItemCalls.append((url))
        let promise = Promise<Result<Void, TethysError>>()
        self.importItemPromises.append(promise)
        return promise.future
    }
}
