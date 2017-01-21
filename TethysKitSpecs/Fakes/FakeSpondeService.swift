import Sponde
import Result
import CBGPromise

class FakeSpondeService: Sponde.Service {
    var generateBookCallCount: Int = 0
    var generateBookStub: ((String, URL?, String, [Chapter], Book.Format) -> Future<Result<Book, SpondeError>>)?
    func generateBookReturns(_ returnValue: Future<Result<Book, SpondeError>>) {
        self.generateBookStub = { _ in returnValue }
    }
    private var generateBookArgs: [(String, URL?, String, [Chapter], Book.Format)] = []
    func generateBookArgsForCall(_ callIndex: Int) -> (String, URL?, String, [Chapter], Book.Format) {
        return self.generateBookArgs[callIndex]
    }
    func generateBook(title: String, imageURL: URL?, author: String, chapters: [Chapter], format: Book.Format) -> Future<Result<Book, SpondeError>> {
        self.generateBookCallCount += 1
        self.generateBookArgs.append((title, imageURL, author, chapters, format))
        return self.generateBookStub!(title, imageURL, author, chapters, format)
    }
}
