import Quick
import Nimble

@testable import TethysKit

func articleService_authors_returnsTheAuthors(line: UInt = #line, file: String = #file,
                                              subjectFactory: @escaping () -> ArticleService) {
    var subject: ArticleService!

    beforeEach {
        subject = subjectFactory()
    }

    context("with one author") {
        it("returns the author's name") {
            let article = articleFactory(authors: [
                Author("An Author")
                ])
            expect(subject.authors(of: article), file: file, line: line).to(equal("An Author"))
        }

        it("returns the author's name and email, if present") {
            let article = articleFactory(authors: [
                Author(name: "An Author", email: URL(string: "mailto:an@author.com"))
                ])
            expect(subject.authors(of: article), file: file, line: line).to(equal("An Author <an@author.com>"))
        }
    }

    context("with two authors") {
        it("returns both authors names") {
            let article = articleFactory(authors: [
                Author("An Author"),
                Author("Other Author", email: URL(string: "mailto:other@author.com"))
            ])

            expect(subject.authors(of: article), file: file, line: line).to(equal("An Author, Other Author <other@author.com>"))
        }
    }

    context("with more authors") {
        it("returns them combined with commas") {
            let article = articleFactory(authors: [
                Author("An Author"),
                Author("Other Author", email: URL(string: "mailto:other@author.com")),
                Author("Third Author", email: URL(string: "mailto:third@other.com"))
            ])

            expect(subject.authors(of: article), file: file, line: line).to(equal(
                "An Author, Other Author <other@author.com>, Third Author <third@other.com>"
            ))
        }
    }
}
