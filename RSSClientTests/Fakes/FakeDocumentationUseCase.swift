import Foundation
import rNews

class FakeDocumentationUseCase: DocumentationUseCase {
    var htmlArgs: [Documentation] = []
    var htmlReturns = ""
    func html(documentation: Documentation) -> String {
        htmlArgs.append(documentation)
        return htmlReturns
    }

    var titleArgs: [Documentation] = []
    var titleReturns = ""
    func title(documentation: Documentation) -> String {
        titleArgs.append(documentation)
        return titleReturns
    }
}
