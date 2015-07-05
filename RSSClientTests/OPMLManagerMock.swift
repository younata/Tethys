import Foundation
@testable import rNewsKit
import Ra

class OPMLManagerMock: OPMLManager {
    var importOPMLURL : NSURL? = nil
    var importOPMLCompletion : ([Feed]) -> Void = {_ in }
    override func importOPML(opml: NSURL, completion: ([Feed]) -> Void) {
        importOPMLURL = opml
        importOPMLCompletion = completion
    }

    var didReceiveWriteOPML = false
    override func writeOPML() {
        didReceiveWriteOPML = true
    }

    convenience init() {
        let injector = Injector()
        injector.bind(DataRepository.self, to: FakeDataRepository())
        injector.bind(kMainQueue, to: NSOperationQueue())
        injector.bind(kBackgroundQueue, to: NSOperationQueue())
        self.init(injector: injector)
    }

    required init(injector: Injector) {
        super.init(injector: injector)
    }
}
