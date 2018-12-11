import Quick
import Nimble
import RealmSwift
@testable import TethysKit

class ArticleSpec: QuickSpec {
    override func spec() {
        var subject: Article! = nil
        var realm: Realm!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "ArticleSpec")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            subject = Article(title: "", link: URL(string: "https://example.com/article1")!, summary: "", authors: [],
                              published: Date(), updatedAt: nil, identifier: "", content: "", read: false)
        }

        describe("Equatable") {
            it("should report two articles created with a realmarticle with the same url as equal") {
                realm.beginWrite()
                let a = realm.create(RealmArticle.self)
                a.link = "https://example.com/article"

                let b = realm.create(RealmArticle.self)
                b.link = "https://example.com/article2"

                _ = try? realm.commitWrite()

                expect(Article(realmArticle: a)).toNot(equal(Article(realmArticle: b)))
                expect(Article(realmArticle: a)).to(equal(Article(realmArticle: a)))
            }

            it("should report two articles not created with datastore objects with the same property equality as equal") {
                let date = Date()
                let a = Article(title: "", link: URL(string: "https://example.com/articlea")!, summary: "", authors: [],
                                published: date, updatedAt: nil, identifier: "", content: "", read: false)
                let b = Article(title: "blah", link: URL(string: "https://example.com")!, summary: "hello",
                                authors: [Author("anAuthor")], published: Date(timeIntervalSince1970: 0),
                                updatedAt: nil, identifier: "hi", content: "hello there", read: true)
                let c = Article(title: "", link: URL(string: "https://example.com/articlea")!, summary: "", authors: [],
                                published: date, updatedAt: nil, identifier: "", content: "", read: false)

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("Hashable") {
            it("should report two articles created with a realmarticle with the same url as equal") {
                realm.beginWrite()
                let a = realm.create(RealmArticle.self)
                a.link = "https://example.com/article"

                let b = realm.create(RealmArticle.self)
                b.link = "https://example.com/article2"

                _ = try? realm.commitWrite()

                expect(Article(realmArticle: a).hashValue).toNot(equal(Article(realmArticle: b).hashValue))
                expect(Article(realmArticle: a).hashValue).to(equal(Article(realmArticle: a).hashValue))
            }

            it("should report two articles not created from datastores with the same property equality as having the same hashValue") {
                let date = Date()
                let a = Article(title: "", link: URL(string: "https://example.com/article1")!, summary: "", authors: [],
                                published: date, updatedAt: nil, identifier: "", content: "", read: false)
                let b = Article(title: "blah", link: URL(string: "https://example.com")!, summary: "hello",
                                authors: [Author("anAuthor")], published: Date(timeIntervalSince1970: 0),
                                updatedAt: nil, identifier: "hi", content: "hello there", read: true)
                let c = Article(title: "", link: URL(string: "https://example.com/article1")!, summary: "", authors: [],
                                published: date, updatedAt: nil, identifier: "", content: "", read: false)

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }
    }
}
