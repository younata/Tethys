import rNews

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

class FakeImportUseCase : ImportUseCase {
    init() {}

    private(set) var scanDirectoryForImportablesCallCount : Int = 0
    private var scanDirectoryForImportablesArgs : Array<(NSURL, ImportUseCaseScanDirectoryCompletion)> = []
    func scanDirectoryForImportablesArgsForCall(callIndex: Int) -> (NSURL, ImportUseCaseScanDirectoryCompletion) {
        return self.scanDirectoryForImportablesArgs[callIndex]
    }
    func scanDirectoryForImportables(url: NSURL, callback: ImportUseCaseScanDirectoryCompletion) {
        self.scanDirectoryForImportablesCallCount++
        self.scanDirectoryForImportablesArgs.append((url, callback))
    }

    private(set) var scanForImportableCallCount : Int = 0
    private var scanForImportableArgs : Array<(NSURL, ImportUseCaseScanCompletion)> = []
    func scanForImportableArgsForCall(callIndex: Int) -> (NSURL, ImportUseCaseScanCompletion) {
        return self.scanForImportableArgs[callIndex]
    }
    func scanForImportable(url: NSURL, callback: ImportUseCaseScanCompletion) {
        self.scanForImportableCallCount += 1
        self.scanForImportableArgs.append((url, callback))
    }

    private(set) var importItemCallCount : Int = 0
    private var importItemArgs : Array<(NSURL, ImportUseCaseImport)> = []
    func importItemArgsForCall(callIndex: Int) -> (NSURL, ImportUseCaseImport) {
        return self.importItemArgs[callIndex]
    }
    func importItem(url: NSURL, callback: ImportUseCaseImport) {
        self.importItemCallCount += 1
        self.importItemArgs.append((url, callback))
    }
}
