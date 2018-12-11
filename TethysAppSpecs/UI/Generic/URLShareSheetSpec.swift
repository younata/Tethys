import Quick
import Nimble

@testable import Tethys

class URLShareSheetSpec: QuickSpec {
    override func spec() {
        var subject: URLShareSheet!
        var themeRepository: ThemeRepository!

        let url = URL(string: "https://example.com/")!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            subject = URLShareSheet(
                url: url,
                themeRepository: themeRepository,
                activityItems: [],
                applicationActivities: []
            )
        }

        describe("when the view lays out it's subviews") {
            beforeEach {
                subject.viewDidLayoutSubviews()
            }

            it("shows a helpful label of the article's url on the sharesheet") {
                expect(subject.view.subviews).to(containElementSatisfying({ (view: UIView) -> Bool in
                    return view.subviews.filter({ $0 is UILabel }).count > 0
                }))
                guard let labelWrapper = subject.view.subviews.filter({ $0.subviews.contains(where: { $0 is UILabel }) }).first else { return }

                guard let label = labelWrapper.subviews.compactMap({ return $0 as? UILabel }).first else { return }

                expect(label.text) == "https://example.com/"

                expect(labelWrapper.backgroundColor) == themeRepository.textColor
                expect(label.textColor) == themeRepository.backgroundColor
            }

            describe("when the view disappears") {
                var labelWrapper: UIView?
                beforeEach {
                    expect(subject.view.subviews).to(containElementSatisfying({ (view: UIView) -> Bool in
                        return view.subviews.filter({ $0 is UILabel }).count > 0
                    }))
                    labelWrapper = subject.view.subviews.filter({ $0.subviews.contains(where: { $0 is UILabel }) }).first

                    subject.viewWillDisappear(false)
                }

                it("hides the labelWrapper") {
                    expect(labelWrapper?.alpha).to(equal(0))
                }

                it("removes the labelWrapper") {
                    expect(labelWrapper).toNot(beNil())
                    expect(labelWrapper?.superview).to(beNil())
                }
            }
        }
    }
}
