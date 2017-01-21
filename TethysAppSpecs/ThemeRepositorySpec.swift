import Quick
import Nimble
import Tethys
import Ra
import UIKit

fileprivate class FakeThemeSubscriber: NSObject, ThemeRepositorySubscriber {
    fileprivate var didCallChangeTheme = false
    fileprivate func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        didCallChangeTheme = true
    }
}

class ThemeRepositorySpec: QuickSpec {
    override func spec() {
        var subject: ThemeRepository! = nil
        var injector: Injector! = nil
        var userDefaults: FakeUserDefaults! = nil
        var subscriber: FakeThemeSubscriber! = nil

        beforeEach {
            injector = Injector()

            userDefaults = FakeUserDefaults()
            injector.bind(kind: UserDefaults.self, toInstance: userDefaults)

            subject = injector.create(kind: ThemeRepository.self)!

            subscriber = FakeThemeSubscriber()
            subject.addSubscriber(subscriber)
            subscriber.didCallChangeTheme = false
        }

        it("adding a subscriber should immediately call didChangeTheme on it") {
            let newSubscriber = FakeThemeSubscriber()
            subject.addSubscriber(newSubscriber)
            expect(newSubscriber.didCallChangeTheme) == true
            expect(subscriber.didCallChangeTheme) == false
        }

        it("has a default theme of .dark") {
            expect(subject.theme).to(equal(ThemeRepository.Theme.dark))
        }

        it("has a default background color of black") {
            expect(subject.backgroundColor).to(equalColor(expectedColor: UIColor.black))
        }

        it("has a default text color of light-gray") {
            expect(subject.textColor).to(equalColor(expectedColor: UIColor(white: 0.85, alpha: 1)))
        }

        it("uses 'darkhub2' as the default article css") {
            expect(subject.articleCSSFileName).to(equal("darkhub2"))
        }

        it("has a default tint color of darkGray") {
            expect(subject.tintColor).to(equalColor(expectedColor: UIColor.darkGray))
        }

        it("uses UIBarStyleBlack as the default barstyle") {
            expect(subject.barStyle).to(equal(UIBarStyle.black))
        }

        it("uses UIStatusBarStyleLightContent as the default statusBarStyle") {
            expect(subject.statusBarStyle).to(equal(UIStatusBarStyle.lightContent))
        }

        it("uses UIScrollViewIndicatorStyleWhite as the default scrollIndicatorStyle") {
            expect(subject.scrollIndicatorStyle).to(equal(UIScrollViewIndicatorStyle.white))
        }

        it("uses UIActivityIndicatorViewStyleWhite as the default spinnerStyle") {
            expect(subject.spinnerStyle).to(equal(UIActivityIndicatorViewStyle.white))
        }

        it("has a default error color of a red shade") {
            expect(subject.errorColor).to(equalColor(expectedColor: UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1)))
        }

        sharedExamples("a changed theme") {(sharedContext: @escaping SharedExampleContext) in
            it("changes the background color") {
                let expectedColor = sharedContext()["background"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.backgroundColor).to(equalColor(expectedColor: expectedColor))
            }

            it("changes the text color") {
                let expectedColor = sharedContext()["text"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.textColor).to(equalColor(expectedColor: expectedColor))
            }

            it("changes the tint color") {
                let expectedColor = sharedContext()["tint"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.tintColor).to(equalColor(expectedColor: expectedColor))
            }

            it("changes the articleCss") {
                let expectedCss = sharedContext()["article"] as? String
                expect(expectedCss).toNot(beNil())
                expect(subject.articleCSSFileName).to(equal(expectedCss))
            }

            it("changes the barstyle") {
                let expectedBarStyle = UIBarStyle(rawValue: sharedContext()["barStyle"] as! Int)
                expect(expectedBarStyle).toNot(beNil())
                expect(subject.barStyle).to(equal(expectedBarStyle))
            }

            it("changes the statusBarStyle") {
                let expectedBarStyle = UIStatusBarStyle(rawValue: sharedContext()["statusBar"] as! Int)
                expect(expectedBarStyle).toNot(beNil())
                expect(subject.statusBarStyle).to(equal(expectedBarStyle))
            }

            it("changes the scrollIndicatorStyle") {
                let expectedScrollIndicatorStyle = UIScrollViewIndicatorStyle(rawValue: sharedContext()["scrollIndicatorStyle"] as! Int)
                expect(expectedScrollIndicatorStyle).toNot(beNil())
                expect(subject.scrollIndicatorStyle).to(equal(expectedScrollIndicatorStyle))
            }

            it("changes the spinnerStyle") {
                let expectedSpinnerStyle = UIActivityIndicatorViewStyle(rawValue: sharedContext()["spinnerStyle"] as! Int)
                expect(expectedSpinnerStyle).toNot(beNil())
                expect(subject.spinnerStyle).to(equal(expectedSpinnerStyle))
            }

            it("changes the error color") {
                let expectedColor = sharedContext()["error"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.errorColor).to(equalColor(expectedColor: expectedColor))
            }

            it("informs subscribers") {
                expect(subscriber.didCallChangeTheme) == true
            }

            it("persists the change if it is not ephemeral") {
                let otherRepo = injector.create(kind: ThemeRepository.self)!
                if (sharedContext()["ephemeral"] as? Bool != true) {
                    let expectedBackground = sharedContext()["background"] as? UIColor
                    expect(expectedBackground).toNot(beNil())

                    let expectedText = sharedContext()["text"] as? UIColor
                    expect(expectedText).toNot(beNil())

                    let expectedCss = sharedContext()["article"] as? String
                    expect(expectedCss).toNot(beNil())

                    let expectedTint = sharedContext()["tint"] as? UIColor
                    expect(expectedTint).toNot(beNil())

                    let expectedBarStyle = UIBarStyle(rawValue: sharedContext()["barStyle"] as! Int)
                    expect(expectedBarStyle).toNot(beNil())

                    let expectedStatusBarStyle = UIStatusBarStyle(rawValue: sharedContext()["statusBar"] as! Int)
                    expect(expectedStatusBarStyle).toNot(beNil())

                    let expectedScrollIndicatorStyle = UIScrollViewIndicatorStyle(rawValue: sharedContext()["scrollIndicatorStyle"] as! Int)
                    expect(expectedScrollIndicatorStyle).toNot(beNil())

                    let expectedSpinnerStyle = UIActivityIndicatorViewStyle(rawValue: sharedContext()["spinnerStyle"] as! Int)
                    expect(expectedSpinnerStyle).toNot(beNil())

                    let expectedError = sharedContext()["error"] as? UIColor
                    expect(expectedError).toNot(beNil())

                    expect(otherRepo.backgroundColor).to(equalColor(expectedColor: expectedBackground))
                    expect(otherRepo.textColor).to(equalColor(expectedColor: expectedText))
                    expect(otherRepo.articleCSSFileName).to(equal(expectedCss))
                    expect(otherRepo.tintColor).to(equalColor(expectedColor: expectedTint))
                    expect(otherRepo.barStyle).to(equal(expectedBarStyle))
                    expect(otherRepo.statusBarStyle).to(equal(expectedStatusBarStyle))
                    expect(otherRepo.scrollIndicatorStyle).to(equal(expectedScrollIndicatorStyle))
                    expect(otherRepo.spinnerStyle).to(equal(expectedSpinnerStyle))
                    expect(otherRepo.errorColor).to(equalColor(expectedColor: expectedError))
                } else {
                    let expectedBackground = UIColor.black
                    let expectedText = UIColor(white: 0.85, alpha: 1)
                    let expectedCss = "darkhub2"
                    let expectedTint = UIColor.darkGray
                    let expectedBarStyle = UIBarStyle.black
                    let expectedStatusBarStyle = UIStatusBarStyle.lightContent
                    let expectedScrollIndicatorStyle = UIScrollViewIndicatorStyle.white
                    let expectedSpinnerStyle = UIActivityIndicatorViewStyle.white
                    let expectedError = UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1)

                    expect(otherRepo.backgroundColor).to(equalColor(expectedColor: expectedBackground))
                    expect(otherRepo.textColor).to(equalColor(expectedColor: expectedText))
                    expect(otherRepo.articleCSSFileName).to(equal(expectedCss))
                    expect(otherRepo.tintColor).to(equalColor(expectedColor: expectedTint))
                    expect(otherRepo.barStyle).to(equal(expectedBarStyle))
                    expect(otherRepo.statusBarStyle).to(equal(expectedStatusBarStyle))
                    expect(otherRepo.scrollIndicatorStyle).to(equal(expectedScrollIndicatorStyle))
                    expect(otherRepo.spinnerStyle).to(equal(expectedSpinnerStyle))
                    expect(otherRepo.errorColor).to(equalColor(expectedColor: expectedError))
                }
            }
        }

        describe("setting the theme") {
            context("of a persistant repository") {
                context("to .dark") {
                    beforeEach {
                        subject.theme = .dark
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.black,
                            "text": UIColor(white: 0.85, alpha: 1),
                            "article": "darkhub2",
                            "tint": UIColor.darkGray,
                            "barStyle": UIBarStyle.black.rawValue,
                            "statusBar": UIStatusBarStyle.lightContent.rawValue,
                            "scrollIndicatorStyle": UIScrollViewIndicatorStyle.white.rawValue,
                            "spinnerStyle": UIActivityIndicatorViewStyle.white.rawValue,
                            "error": UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1),
                        ]
                    }
                }

                context("to .light") {
                    beforeEach {
                        subject.theme = .light
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.white,
                            "text": UIColor.black,
                            "article": "github2",
                            "tint": UIColor.white,
                            "barStyle": UIBarStyle.default.rawValue,
                            "statusBar": UIStatusBarStyle.default.rawValue,
                            "scrollIndicatorStyle": UIScrollViewIndicatorStyle.black.rawValue,
                            "spinnerStyle": UIActivityIndicatorViewStyle.gray.rawValue,
                            "error": UIColor(red: 1, green: 0, blue: 0.2, alpha: 1),
                        ]
                    }
                }
            }

            context("of an ephemeral repository") {
                beforeEach {
                    subject = ThemeRepository(userDefaults: nil)

                    subscriber = FakeThemeSubscriber()
                    subject.addSubscriber(subscriber)
                    subscriber.didCallChangeTheme = false
                }
                
                context("to .dark") {
                    beforeEach {
                        subject.theme = .dark
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.black,
                            "text": UIColor(white: 0.85, alpha: 1),
                            "article": "darkhub2",
                            "tint": UIColor.darkGray,
                            "barStyle": UIBarStyle.black.rawValue,
                            "statusBar": UIStatusBarStyle.lightContent.rawValue,
                            "scrollIndicatorStyle": UIScrollViewIndicatorStyle.white.rawValue,
                            "spinnerStyle": UIActivityIndicatorViewStyle.white.rawValue,
                            "error": UIColor(red: 0.75, green: 0, blue: 0.1, alpha: 1),
                            "ephemeral": true,
                        ]
                    }
                }

                context("to .light") {
                    beforeEach {
                        subject.theme = .light
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.white,
                            "text": UIColor.black,
                            "article": "github2",
                            "tint": UIColor.white,
                            "barStyle": UIBarStyle.default.rawValue,
                            "statusBar": UIStatusBarStyle.default.rawValue,
                            "scrollIndicatorStyle": UIScrollViewIndicatorStyle.black.rawValue,
                            "spinnerStyle": UIActivityIndicatorViewStyle.gray.rawValue,
                            "error": UIColor(red: 1, green: 0, blue: 0.2, alpha: 1),
                            "ephemeral": true,
                        ]
                    }
                }
            }
        }
    }
}
