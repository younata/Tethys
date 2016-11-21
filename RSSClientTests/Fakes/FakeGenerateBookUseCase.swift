import rNewsKit
import CBGPromise
import Result
import Sponde

final class FakeGenerateBookUseCase: GenerateBookUseCase {
    var generateBookCallCount: Int = 0
    var generateBookStub: ((String, String, [Article], Book.Format) -> Future<Result<URL, RNewsError>>)?
    func generateBookReturns(_ returnValue: Future<Result<URL, RNewsError>>) {
        self.generateBookStub = { _ in returnValue }
    }
    private var generateBookArgs: [(String, String, [Article], Book.Format)] = []
    func generateBookArgsForCall(_ callIndex: Int) -> (String, String, [Article], Book.Format) {
        return self.generateBookArgs[callIndex]
    }
    func generateBook(title: String, author: String, chapters: [Article], format: Book.Format) -> Future<Result<URL, RNewsError>> {
        self.generateBookCallCount += 1
        self.generateBookArgs.append((title, author, chapters, format))
        return self.generateBookStub!(title, author, chapters, format)
    }
}
