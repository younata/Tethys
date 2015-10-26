import Quick
import Nimble
import rNews
import Ra
import UIKit

private class FakeThemeSubscriber: NSObject, ThemeRepositorySubscriber {
    private var didCallChangeTheme = false
    private func didChangeTheme() {
        didCallChangeTheme = true
    }
}

class ThemeRepositorySpec: QuickSpec {
    override func spec() {
        var subject: ThemeRepository! = nil
        var injector: Injector! = nil
        var userDefaults: NSUserDefaults! = nil
        var subscriber: FakeThemeSubscriber! = nil

        beforeEach {
            injector = Injector()

            userDefaults = NSUserDefaults()
            injector.bind(NSUserDefaults.self, to: userDefaults)

            subject = injector.create(ThemeRepository.self) as! ThemeRepository

            subscriber = FakeThemeSubscriber()
            subject.addSubscriber(subscriber)
            subscriber.didCallChangeTheme = false
        }

        it("adding a subscriber should immediately call didChangeTheme on it") {
            let newSubscriber = FakeThemeSubscriber()
            subject.addSubscriber(newSubscriber)
            expect(newSubscriber.didCallChangeTheme).to(beTruthy())
            expect(subscriber.didCallChangeTheme).to(beFalsy())
        }

        it("has a default theme of .Default") {
            expect(subject.theme).to(equal(ThemeRepository.Theme.Default))
        }

        it("has a default background color of white") {
            expect(subject.backgroundColor).to(equal(UIColor.whiteColor()))
        }

        it("has a default text color of black") {
            expect(subject.textColor).to(equal(UIColor.blackColor()))
        }

        it("uses 'github2' as the default article css") {
            expect(subject.articleCSSFileName).to(equal("github2"))
        }

        it("has a default tint color of white") {
            expect(subject.tintColor).to(equal(UIColor.whiteColor()))
        }

        describe("setting the theme") {
            sharedExamples("a changed theme") {(sharedContext: SharedExampleContext) in
                it("changes the background color") {
                    let expectedColor = sharedContext()["background"] as? UIColor
                    expect(expectedColor).toNot(beNil())
                    expect(subject.backgroundColor).to(equal(expectedColor))
                }

                it("changes the text color") {
                    let expectedColor = sharedContext()["text"] as? UIColor
                    expect(expectedColor).toNot(beNil())
                    expect(subject.textColor).to(equal(expectedColor))
                }

                it("changes the tint color") {
                    let expectedColor = sharedContext()["tint"] as? UIColor
                    expect(expectedColor).toNot(beNil())
                    expect(subject.tintColor).to(equal(expectedColor))
                }

                it("changes the articleCss") {
                    let expectedCss = sharedContext()["article"] as? String
                    expect(expectedCss).toNot(beNil())
                    expect(subject.articleCSSFileName).to(equal(expectedCss))
                }

                it("informs subscribers") {
                    expect(subscriber.didCallChangeTheme).to(beTruthy())
                }

                it("persists the change") {
                    let otherRepo = injector.create(ThemeRepository.self) as! ThemeRepository

                    let expectedBackground = sharedContext()["background"] as? UIColor
                    expect(expectedBackground).toNot(beNil())

                    let expectedText = sharedContext()["text"] as? UIColor
                    expect(expectedText).toNot(beNil())

                    let expectedCss = sharedContext()["article"] as? String
                    expect(expectedCss).toNot(beNil())

                    let expectedTint = sharedContext()["tint"] as? UIColor
                    expect(expectedTint).toNot(beNil())

                    expect(otherRepo.backgroundColor).to(equal(expectedBackground))
                    expect(otherRepo.textColor).to(equal(expectedText))
                    expect(otherRepo.articleCSSFileName).to(equal(expectedCss))
                    expect(otherRepo.tintColor).to(equal(expectedTint))
                }
            }

            context("to .Dark") {
                beforeEach {
                    subject.theme = .Dark
                }

                itBehavesLike("a changed theme") {
                    return [
                        "background": UIColor.blackColor(),
                        "text": UIColor.whiteColor(),
                        "article": "darkhub2",
                        "tint": UIColor.darkGrayColor(),
                    ]
                }
            }

            context("to .Default") {
                beforeEach {
                    subject.theme = .Default
                }

                itBehavesLike("a changed theme") {
                    return [
                        "background": UIColor.whiteColor(),
                        "text": UIColor.blackColor(),
                        "article": "github2",
                        "tint": UIColor.whiteColor(),
                    ]
                }
            }
        }
    }
}