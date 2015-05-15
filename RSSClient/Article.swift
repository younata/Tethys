import Foundation

struct Article : Equatable, Hashable {
    var title : String
    var link : NSURL?
    var summary : String
    var author : String
    var published : NSDate
    var updatedAt : NSDate?
    var identifier : String
    var content : String
    var read : Bool
    var feed : Feed?
    var flags : [String]
    internal private(set) var enclosures : [Enclosure] = []

    private(set) var updated : Bool = false

    var hashValue : Int {
        return 0
    }

    init(title: String, link: NSURL?, summary: String, author: String, published: NSDate,
        updatedAt: NSDate?, identifier: String, content: String, read: Bool, feed: Feed?,
        flags: [String], enclosures: [Enclosure]) {
            self.title = title
            self.link = link
            self.summary = summary
            self.author = author
            self.published = published
            self.updatedAt = updatedAt
            self.identifier = identifier
            self.content = content
            self.read = read
            self.feed = feed
            self.flags = flags
            self.enclosures = enclosures
            updated = false
    }

    private(set) var articleID : NSManagedObjectID? = nil

    init(article: CoreDataArticle, feed: Feed?) {
        title = article.title ?? ""
        if let articleLink = article.link {
            link = NSURL(string: articleLink)
        } else {
            link = nil
        }

        summary = article.summary ?? ""
        author = article.author ?? ""
        published = article.published
        updatedAt = article.updatedAt
        identifier = article.identifier ?? ""
        content = article.content ?? ""
        read = article.read
        self.feed = feed
        flags = article.flags as? [String] ?? []
        if let articleEnclosures = article.enclosures as? Set<CoreDataEnclosure> {
            let enclosuresList = Array(articleEnclosures)
            enclosures = enclosuresList.map { Enclosure(enclosure: $0, article: self) }
        } else {
            enclosures = []
        }

        updated = false

        articleID = article.objectID
    }

    mutating func addFlag(flag: String) {
        if !contains(self.flags, flag) {
            self.flags.append(flag)
            updated = true
        }
    }

    mutating func removeFlag(flag: String) {
        if contains(self.flags, flag) {
            self.flags = self.flags.filter { $0 != flag }
            updated = true
        }
    }

//    mutating func addEnclosure(enclosure: Enclosure) {
//        if !contains(self.enclosures, enclosure) {
//            self.enclosures.append(enclosure)
//            updated = true
//        }
//    }
//
//    mutating func removeEnclosure(enclosure: Enclosure) {
//        if contains(self.enclosures, enclosure) {
//            self.enclosures = self.enclosures.filter { $0 != enclosure }
//            updated = true
//        }
//    }
}

func ==(a: Article, b: Article) -> Bool {
    return true
}