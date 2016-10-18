import Quick
import Nimble
import rNews

class ArticleListHeaderCellSpec: QuickSpec {
    override func spec() {
        var subject: ArticleListHeaderCell!
        var themeRepository: ThemeRepository!

        beforeEach {
            subject = ArticleListHeaderCell(style: .default, reuseIdentifier: nil)

            themeRepository = ThemeRepository(userDefaults: nil)
            subject.themeRepository = themeRepository
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates each label") {
                expect(subject.summary.textColor) == themeRepository.textColor
            }

            it("changes the cell's background colors") {
                expect(subject.backgroundColor) == themeRepository.backgroundColor
            }
        }

        describe("configure") {
            context("with an image") {
                let image = UIImage(named: "GrayIcon")
                beforeEach {
                    subject.configure(summary: "test", image: image)
                }

                it("shows the image") {
                    expect(subject.iconView.image) == image
                }

                it("sets the width or height constraint depending on the image size") {
                    // in this case, 60x60
                    expect(subject.iconWidth.constant) == 60
                    expect(subject.iconHeight.constant) == 60
                }

                it("sets the summary") {
                    expect(subject.summary.text) == "test"
                }
            }

            context("without an image") {
                beforeEach {
                    subject.configure(summary: "test", image: nil)
                }

                it("sets an image of nil") {
                    expect(subject.iconView.image).to(beNil())
                }

                it("sets the width and height to 0") {
                    expect(subject.iconWidth.constant) == 0
                    expect(subject.iconHeight.constant) == 0
                }

                it("sets the summary") {
                    expect(subject.summary.text) == "test"
                }
            }
        }
    }
}
