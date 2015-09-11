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
        var opmlManager: OPMLManagerMock! = nil
        var dataReadWriter: FakeDataReadWriter! = nil

        beforeEach {
            window = NSWindow()

            subject = MainController()
            subject.window = window

            injector = Injector()
            subject.configure(injector)

            opmlManager = OPMLManagerMock()
            injector.bind(OPMLManager.self, to: opmlManager)

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataRetriever.self, to: dataReadWriter)
            injector.bind(DataWriter.self, to: dataReadWriter)

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

        it("passes the injector to the feedsList") {
            expect(subject.feedsList.raInjector).to(beIdenticalTo(injector))
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

                var fakeUrls = Array<NSURL>()
                override var URLs: [NSURL] {
                    return fakeUrls
                }
            }

            var openPanel: FakeOpenPanel! = nil

            let urlToImport = NSURL(string: "file:///Users/Shared/opml.xml")!

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

            context("when the user selects a file") {
                beforeEach {
                    openPanel.fakeUrls = [urlToImport]
                    openPanel.sheetModalHandler(NSFileHandlingPanelOKButton)
                }

                it("should reach out to the opmlManager") {
                    expect(opmlManager.importOPMLURL).to(equal(urlToImport))
                }

                context("and the file is actually an opml file") {
                    let feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    beforeEach {
                        opmlManager.importOPMLCompletion([feed])
                    }

                    it("should ask the dataWriter to update feeds") {
                        expect(dataReadWriter.didUpdateFeeds).to(beTruthy())
                    }

                    // show something to indicate that things are going fine
                }

                context("and the file is not an opml file") {
                    beforeEach {
                        opmlManager.importOPMLCompletion([])
                    }

                    it("should not ask the dataWriter to update feeds") {
                        expect(dataReadWriter.didUpdateFeeds).to(beFalsy())
                    }

                    // pop up something to let the user know they dun goofed.
                }
            }
        }
    }
}
