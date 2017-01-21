import Quick
import Nimble
import CBGPromise
import Result
import Sponde
@testable import TethysKit

class GenerateBookUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: GenerateBookUseCase!
        var spondeService: FakeSpondeService!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            spondeService = FakeSpondeService()
            mainQueue = FakeOperationQueue()

            subject = DefaultGenerateBookUseCase(service: spondeService, mainQueue: mainQueue)
        }

        describe("generateBook(title:author:chapters:)") {
            let articles: [Article] = [
                Article(title: "Article 1", link: URL(string: "https://example.com/1")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "contents of chapter 1", read: false,
                        synced: false, estimatedReadingTime: 0, feed: nil, flags: []),
                Article(title: "Article 2", link: URL(string: "https://example.com/2")!, summary: "contents of chapter 2", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "   \n\t   ", read: false,
                        synced: false, estimatedReadingTime: 0, feed: nil, flags: []),
                Article(title: "Article 3", link: URL(string: "https://example.com/3")!, summary: "chapter 3 contents", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, estimatedReadingTime: 0, feed: nil, flags: []),
                Article(title: "Article 4", link: URL(string: "https://example.com/4")!, summary: "", authors: [],
                        published: Date(), updatedAt: nil, identifier: "", content: "", read: false,
                        synced: false, estimatedReadingTime: 0, feed: nil, flags: []),
                ]

            var generateBookPromise: Promise<Result<Book, SpondeError>>!
            var receivedFuture: Future<Result<URL, TethysError>>!
            beforeEach {
                generateBookPromise = Promise<Result<Book, SpondeError>>()

                spondeService.generateBookReturns(generateBookPromise.future)

                receivedFuture = subject.generateBook(title: "my title", author: "an author", chapters: articles, format: Book.Format.epub)
            }

            it("returns an in-progress future") {
                expect(receivedFuture.value).to(beNil())
            }

            it("makes a call to the sponde service") {
                expect(spondeService.generateBookCallCount) == 1
            }

            it("passes along the arguments") {
                guard spondeService.generateBookCallCount == 1 else { fail("call spondeservice"); return }
                let args = spondeService.generateBookArgsForCall(0)

                expect(args.0) == "my title"
                expect(args.1).to(beNil())
                expect(args.2) == "an author"
                expect(args.4) == Book.Format.epub
            }

            it("converts the articles to book chapters") {
                guard spondeService.generateBookCallCount == 1 else { fail("call spondeservice"); return }
                let chapters = spondeService.generateBookArgsForCall(0).3

                let expected: [(title: String, content: String?, url: URL?)] = [
                    (title: "Article 1", content: "contents of chapter 1", url: nil),
                    (title: "Article 2", content: "contents of chapter 2", url: nil),
                    (title: "Article 3", content: "chapter 3 contents", url: nil),
                    (title: "Article 4", content: nil, url: URL(string: "https://example.com/4")!)
                ]

                expect(chapters.count) == expected.count
                for i in 0..<chapters.count {
                    let chapter = chapters[i]
                    let article = expected[i]

                    expect(chapter.title) == article.title
                    if let _ = article.content {
                        expect(chapter.html) == article.content
                    } else {
                        expect(chapter.html).to(beNil())
                    }
                    if let _ = article.url {
                        expect(chapter.url) == article.url
                    } else {
                        expect(chapter.url).to(beNil())
                    }
                }
            }

            describe("when the service succeeds") {
                let book = Book(filename: "my_book.epub", format: .epub, content: "foo".data(using: .utf8)!)

                beforeEach {
                    generateBookPromise.resolve(.success(book))
                }

                it("adds an operation to the main queue") {
                    expect(mainQueue.operationCount) == 1
                }

                describe("and the operation runs") {
                    beforeEach {
                        while mainQueue.operationCount != 0 {
                            mainQueue.runNextOperation()
                        }
                    }
                    var receivedURL: URL?

                    beforeEach {
                        receivedURL = receivedFuture.value?.value
                    }

                    afterEach {
                        if let url = receivedURL {
                            try! FileManager.default.removeItem(at: url)
                        }
                    }

                    it("writes the book to a url") {
                        expect(receivedURL).toNot(beNil())

                        expect(receivedURL?.lastPathComponent) == "my_book.epub"

                        if let url = receivedURL {
                            let data = try! String(contentsOf: url)
                            expect(data) == "foo"
                        }
                    }
                }
            }

            describe("when the service fails") {
                beforeEach {
                    generateBookPromise.resolve(.failure(.invalidRequest("unknown")))
                }

                it("adds an operation to the main queue") {
                    expect(mainQueue.operationCount) == 1
                }

                describe("and the operation runs") {
                    beforeEach {
                        while mainQueue.operationCount != 0 {
                            mainQueue.runNextOperation()
                        }
                    }

                    it("informs the caller of the error") {
                        expect(receivedFuture.value).toNot(beNil())

                        expect(receivedFuture.value?.value).to(beNil())
                        expect(receivedFuture.value?.error) == .book(.invalidRequest("unknown"))
                    }
                }
            }
        }
    }
}
