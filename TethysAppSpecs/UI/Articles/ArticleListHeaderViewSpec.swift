import Quick
import Nimble
@testable import Tethys

class ArticleListHeaderViewSpec: QuickSpec {
    override func spec() {
        var subject: ArticleListHeaderView!

        beforeEach {
            subject = ArticleListHeaderView()
            subject.translatesAutoresizingMaskIntoConstraints = false
        }

        describe("theming") {
            it("sets each label's textcolor") {
                expect(subject.summary.textColor).to(equal(Theme.textColor))
            }

            it("changes the background colors") {
                expect(subject.backgroundColor).to(equal(Theme.backgroundColor))
            }
        }

        describe("configure") {
            context("with an image") {
                let image = UIImage(named: "GrayIcon")
                beforeEach {
                    subject.configure(summary: "test", image: image)
                    subject.layoutIfNeeded()
                }

                it("shows the image") {
                    expect(subject.iconView.image).to(be(image))
                    expect(subject.iconView.isHidden).to(beFalse())
                }

                it("sets the width or height constraint depending on the image size") {
                    // in this case, 60x60
                    expect(subject.iconView.bounds.width).to(equal(60))
                    expect(subject.iconView.bounds.height).to(equal(60))
                }

                it("sets the summary") {
                    expect(subject.summary.text).to(equal("test"))
                }
            }

            context("without an image") {
                beforeEach {
                    subject.configure(summary: "test", image: nil)
                    subject.layoutIfNeeded()
                }

                it("sets an image of nil") {
                    expect(subject.iconView.image).to(beNil())
                }

                it("hides the iconView") {
                    expect(subject.iconView.isHidden).to(beTrue())
                }

                it("sets the summary") {
                    expect(subject.summary.text).to(equal("test"))
                }
            }
        }
    }
}
