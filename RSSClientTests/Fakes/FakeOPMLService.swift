import Foundation
@testable import rNewsKit
import Ra

class FakeOPMLService: OPMLService {
    var importOPMLURL : URL? = nil
    var importOPMLCompletion : ([Feed]) -> Void = {_ in }
    override func importOPML(_ opml: URL, completion: ([Feed]) -> Void) {
        importOPMLURL = opml
        importOPMLCompletion = completion
    }

    var didReceiveWriteOPML = false
    override func writeOPML() {
        didReceiveWriteOPML = true
    }

    convenience init() {
        self.init(injector: Injector())
    }

    required init(injector: Injector) {
        super.init(injector: injector)
    }
}
