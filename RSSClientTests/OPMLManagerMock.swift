import Foundation
import rNews

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

    init() {
        super.init(dataManager: DataManagerMock(), mainQueue: NSOperationQueue(), importQueue: NSOperationQueue())
    }
}
