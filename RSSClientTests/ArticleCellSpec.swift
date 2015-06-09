import Quick
import Nimble
import rNews

class ArticleCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleCell! = nil

        beforeEach {
            subject = ArticleCell(style: .Default, reuseIdentifier: nil)
        }
    }
}
