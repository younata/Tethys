import Quick
import Nimble
import Cocoa
import rNews
import rNewsKit
import Ra

class MainControllerSpec: QuickSpec {
    override func spec() {
        var subject: MainController! = nil
        var window: NSWindow? = nil
        var injector: Injector! = nil

        beforeEach {
            window = NSWindow()

            subject = MainController()
            subject.window = window

            injector = Injector()
            subject.configure(injector)

            subject.view = NSView()
            subject.viewDidLoad()
        }

        it("becomes the first responder") {
            expect(window?.firstResponder).to(equal(subject))
        }

        it("starts with one item in the split view") {
            expect(subject.splitViewController.splitViewItems.count).to(equal(1))
            expect(subject.splitViewController.splitViewItemForViewController(subject.feedsList)).toNot(beNil())
        }

        describe("showing articles") {
            let feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            beforeEach {
                subject.feedsList.onFeedSelection(feed)
            }
        }

        describe("Importing OPML files") {
            class FakeOpenPanel: NSOpenPanel {
                var sheetModalWindow: NSWindow? = nil
                var sheetModalHandler: (Int) -> (Void) = {_ in}
                override func beginSheetModalForWindow(window: NSWindow, completionHandler handler: (Int) -> Void) {
                    self.sheetModalWindow = window
                    self.sheetModalHandler = handler
                }
            }

            var openPanel: FakeOpenPanel! = nil

            beforeEach {
                openPanel = FakeOpenPanel()
                injector.bind(NSOpenPanel.self, to: openPanel)
                subject.openDocument(self)
            }

            it("should open a dialog to find something") {
                expect(openPanel.canChooseDirectories).to(beFalsy())
                expect(openPanel.allowsMultipleSelection).to(beTruthy())
                expect(openPanel.allowedFileTypes).to(equal(["opml", "xml"]))
                expect(openPanel.sheetModalWindow).toNot(beNil())
            }

            sharedExamples("an opml import attempt") {
            }

            context("when the user selects a valid opml file") {
                itBehavesLike("an opml import attempt")
            }

            context("when the user selects something not a valid opml file") {
                itBehavesLike("an opml import attempt")
            }
        }
    }
}
