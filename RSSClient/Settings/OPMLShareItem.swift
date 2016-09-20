import UIKit
import Ra
import rNewsKit
import CBGPromise
import Result

public class OPMLShareItem: UIActivityItemProvider, Injectable {
    private let generateOPMLFuture: Future<Result<String, RNewsError>>
    public required init(injector: Injector) {
        let opmlService = injector.create(kind: OPMLService.self)!
        self.generateOPMLFuture = opmlService.writeOPML()
        super.init(placeholderItem: NSData())
    }

    public override var item: Any {
        return (self.generateOPMLFuture.wait()?.value ?? "").data(using: String.Encoding.utf8)
    }

    public override func activityViewController(_ activityViewController: UIActivityViewController,
                                                dataTypeIdentifierForActivityType activityType: UIActivityType?) -> String {
        return "com.rachelbrindle.rssclient.opml"
    }

    public override func activityViewController(_ activityViewController: UIActivityViewController,
                                                subjectForActivityType activityType: UIActivityType?) -> String {
        return NSLocalizedString("OPMLShareItem_Name", comment: "")
    }
}
