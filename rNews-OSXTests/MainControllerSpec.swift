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
        var importUseCase: FakeImportUseCase! = nil

        beforeEach {
            window = NSWindow()

            subject = MainController()
            subject.window = window

            injector = Injector()
            subject.configure(injector)

            importUseCase = FakeImportUseCase()
            injector.bind(kind: ImportUseCase.self, toInstance: importUseCase)

            subject.view = NSView()
            subject.viewDidLoad()
        }

        it("becomes the first responder") {
            expect(window?.firstResponder).to(equal(subject))
        }

        it("starts with one item in the split view") {
            expect(subject.splitViewController.splitViewItems.count).to(equal(1))
            expect(subject.splitViewController.splitViewItem(for: subject.feedsList)).toNot(beNil())
        }

        it("passes the injector to the feedsList") {
            expect(subject.feedsList.raInjector).to(beIdenticalTo(injector))
        }

        describe("showing articles") {
            let feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let article = Article(title: "", link: URL(string: "https://example.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, estimatedReadingTime: 0, feed: nil, flags: [])
            feed.addArticle(article)

            let articles = DataStoreBackedArray<Article>([article])

            beforeEach {
                subject.feedsList.onFeedSelection(feed)
            }

            it("creates an ArticleListViewController") {
                expect(subject.articlesList).toNot(beNil())
                expect(Array(subject.articlesList!.articles)) == Array(articles)
            }

            it("adds an item to the splitView") {
                expect(subject.splitViewController.splitViewItems.count).to(equal(2))
                if let articlesList = subject.articlesList {
                    expect(subject.splitViewController.splitViewItem(for: articlesList)).toNot(beNil())
                }
            }
        }

        describe("Importing OPML files") {
            class FakeOpenPanel: NSOpenPanel {
                var sheetModalWindow: NSWindow? = nil
                var sheetModalHandler: (Int) -> (Void) = {_ in}
                override func beginSheetModal(for window: NSWindow, completionHandler handler: @escaping (Int) -> Void) {
                    self.sheetModalWindow = window
                    self.sheetModalHandler = handler
                }

                var fakeUrls = Array<URL>()
                override var urls: [URL] {
                    return fakeUrls
                }
            }

            var openPanel: FakeOpenPanel! = nil

            let urlToImport = URL(string: "file:///Users/Shared/opml.xml")!

            beforeEach {
                openPanel = FakeOpenPanel()
                injector.bind(kind: NSOpenPanel.self, toInstance: openPanel)
                subject.openDocument(self)
            }

            it("should open a dialog to find something") {
                expect(openPanel.canChooseDirectories) == false
                expect(openPanel.allowsMultipleSelection) == true
                expect(openPanel.allowedFileTypes).to(equal(["opml", "xml"]))
                expect(openPanel.sheetModalWindow).toNot(beNil())
            }

//            context("when the user selects a file") {
//                beforeEach {
//                    openPanel.fakeUrls = [urlToImport]
//                    openPanel.sheetModalHandler(NSFileHandlingPanelOKButton)
//                }
//
//                it("should reach out to the opmlManager") {
//                    expect(opmlManager.importOPMLURL).to(equal(urlToImport))
//                }
//
//                context("and the file is actually an opml file") {
//                    let feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
//                    beforeEach {
//                        opmlManager.importOPMLCompletion([feed])
//                    }
//
//                    it("should ask the dataWriter to update feeds") {
//                        expect(dataWriter.didUpdateFeeds) == true
//                    }
//
//                    // show something to indicate that things are going fine
//                }
//
//                context("and the file is not an opml file") {
//                    beforeEach {
//                        opmlManager.importOPMLCompletion([])
//                    }
//
//                    it("should not ask the dataWriter to update feeds") {
//                        expect(dataWriter.didUpdateFeeds) == false
//                    }
//
//                    // pop up something to let the user know they dun goofed.
//                }
//            }
        }
    }
}
