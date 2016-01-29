import RealmSwift
import Foundation

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

class RealmService: DataService {
    private let realm: Realm
    private let mainQueue: NSOperationQueue

    let searchIndex: SearchIndex?

    init(realm: Realm, mainQueue: NSOperationQueue, searchIndex: SearchIndex?) {
        self.realm = realm
        self.mainQueue = mainQueue
        self.searchIndex = searchIndex
    }

    func createFeed(callback: (Feed) -> (Void)) {
    }

    func createArticle(feed: Feed?, callback: (Article) -> (Void)) {
    }

    func createEnclosure(article: Article?, callback: (Enclosure) -> (Void)) {
    }

    // Mark: - Read

    func feedsMatchingPredicate(predicate: NSPredicate, callback: [Feed] -> Void) {
//        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
    }

    func articlesMatchingPredicate(predicate: NSPredicate, callback: [Article] -> Void) {
//        let sortDescriptors = [
//            NSSortDescriptor(key: "updatedAt", ascending: false),
//            NSSortDescriptor(key: "published", ascending: false)
//        ]
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: [Enclosure] -> Void) {
//        let sortDescriptors = [NSSortDescriptor(key: "kind", ascending: true)]
    }

    // Mark: - Update

    func saveFeed(feed: Feed, callback: (Void) -> (Void)) {

    }

    func saveArticle(article: Article, callback: (Void) -> (Void)) {

    }

    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {

    }

    // Mark: - Delete

    func deleteFeed(feed: Feed, callback: (Void) -> (Void)) {
        let articleIdentifiers = feed.articlesArray.map { $0.identifier }
            #if os(iOS)
                if #available(iOS 9, *) {
                    self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
                }
            #endif
    }

    func deleteArticle(article: Article, callback: (Void) -> (Void)) {
    }

    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
    }

    private func realmFeedForFeed(feed: Feed) -> RealmFeed? {
        return self.realm.objects(RealmFeed).filter("url = \(feed.url!.absoluteString)").first
    }

    // Synchronous update!

    private func updateFeed(feed: Feed) {
        if let rfeed = self.realmFeedForFeed(feed) {
            rfeed.title = feed.title
            rfeed.summary = feed.summary
            rfeed.query = feed.query
            let tags: [RealmString] = feed.tags.map { str in
                let realmString = RealmString()
                realmString.string = str
                return realmString
            }
            rfeed.tags.replaceRange(0..<rfeed.tags.count, with: tags)
            rfeed.waitPeriod = feed.waitPeriod
            rfeed.remainingWait = feed.remainingWait
            #if os(iOS)
                if let image = feed.image {
                    rfeed.imageData = UIImagePNGRepresentation(image)
                }
            #else
                if let image = feed.image {
                    rfeed.imageData = image.TIFFRepresentation
                }
            #endif
        }
    }
}
