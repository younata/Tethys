import CBGPromise
import Result
import Sponde

public protocol GenerateBookUseCase {
    func generateBook(title: String, author: String,
                      chapters: [Article], format: Book.Format) -> Future<Result<URL, TethysError>>
}

struct DefaultGenerateBookUseCase: GenerateBookUseCase {
    let service: Sponde.Service
    let mainQueue: OperationQueue

    init(service: Sponde.Service, mainQueue: OperationQueue) {
        self.service = service
        self.mainQueue = mainQueue
    }

    func generateBook(title: String, author: String,
                      chapters: [Article], format: Book.Format) -> Future<Result<URL, TethysError>> {
        let bookChapters = chapters.map { article -> Chapter in
            let articleContent = article.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let content = articleContent.isEmpty ? article.summary : articleContent
            if content.isEmpty {
                return Chapter(title: article.title, url: article.link)
            } else {
                return Chapter(title: article.title, html: content)
            }
        }
        let future = self.service.generateBook(title: title, imageURL: nil, author: author,
                                               chapters: bookChapters, format: format)
        return future.map { (result: Result<Book, SpondeError>) -> Future<Result<URL, TethysError>> in
            let promise = Promise<Result<URL, TethysError>>()
            self.mainQueue.addOperation {
                switch result {
                case let .success(book):
                    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                    let bookURL = tempDirectory.appendingPathComponent(book.filename, isDirectory: false)
                    try? book.content.write(to: bookURL)
                    promise.resolve(.success(bookURL))
                case let .failure(error):
                    promise.resolve(.failure(TethysError.book(error)))
                }
            }
            return promise.future
        }
    }
}
