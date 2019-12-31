import Quick
import Nimble
import RealmSwift
@testable import TethysKit

class FeedSpec: QuickSpec {
    override func spec() {
        var subject: Feed! = nil
        var realm: Realm!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "FeedSpec")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [])
        }

        it("uses it's url as the title if the title is blank") {
            subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [])

            expect(subject.displayTitle).to(equal("https://example.com"))
        }

        describe("Equatable") {
            it("reports two feeds created with a realmfeed with the same url as equal") {
                let a = RealmFeed()
                a.url = "https://example.com/feed"
                let b = RealmFeed()
                b.url = "https://example.com/feed2"

                _ = try? realm.write {
                    realm.add(a)
                    realm.add(b)
                }

                expect(Feed(realmFeed: a)).toNot(equal(Feed(realmFeed: b)))
                expect(Feed(realmFeed: a)).to(equal(Feed(realmFeed: a)))
            }

            context("when the feeds aren't created from the same datastore") {
                it("is true when all properties are equal") {
                    expect(Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a"], unreadCount: 10, image: nil)).to(equal(
                        Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a"], unreadCount: 10, image: nil)
                    ))
                }

                it("is false when titles differ") {
                    expect(Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "", tags: [], unreadCount: 0, image: nil)).toNot(equal(
                        Feed(title: "bar", url: URL(string: "https://example.com")!, summary: "", tags: [], unreadCount: 0, image: nil)
                    ))
                }

                it("is false when the urls differ") {
                    expect(Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a"], unreadCount: 10, image: nil)).toNot(equal(
                        Feed(title: "foo", url: URL(string: "https://example.com/bar")!, summary: "a summary", tags: ["a"], unreadCount: 10, image: nil)
                    ))
                }

                it("is false when the summaries differ") {
                    expect(Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a"], unreadCount: 10, image: nil)).toNot(equal(
                        Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "different summary", tags: ["a"], unreadCount: 10, image: nil)
                    ))
                }

                it("is false when the tags differ") {
                    expect(Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a", "c"], unreadCount: 10, image: nil)).toNot(equal(
                        Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a", "b"], unreadCount: 10, image: nil)
                    ))
                }

                it("is false when the unreadCounts differ") {
                    expect(Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a"], unreadCount: 10, image: nil)).toNot(equal(
                        Feed(title: "foo", url: URL(string: "https://example.com")!, summary: "a summary", tags: ["a"], unreadCount: 5, image: nil)
                    ))
                }
            }
        }

        describe("Hashable") {
            it("should report two feeds created with a realmfeed with the same url as having the same hashValue") {
                let a = RealmFeed()
                a.url = "https://example.com/feed"
                let b = RealmFeed()
                b.url = "https://example.com/feed2"

                _ = try? realm.write {
                    realm.add(a)
                    realm.add(b)
                }

                expect(Feed(realmFeed: a).hashValue).toNot(equal(Feed(realmFeed: b).hashValue))
                expect(Feed(realmFeed: a).hashValue).to(equal(Feed(realmFeed: a).hashValue))
            }

            it("should report two feeds not created from datastores with the same property equality as having the same hashValue") {
                let a = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], unreadCount: 0, image: nil)
                let b = Feed(title: "blah", url: URL(string: "https://example.com")!, summary: "", tags: [], unreadCount: 0, image: nil)
                let c = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], unreadCount: 0, image: nil)

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }
    }
}
