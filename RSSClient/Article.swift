import Foundation

class Article : Equatable, Hashable {
    var title : String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    var link : NSURL? {
        willSet {
            if newValue != link {
                self.updated = true
            }
        }
    }
    var summary : String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }
    var author : String {
        willSet {
            if newValue != author {
                self.updated = true
            }
        }
    }
    var published : NSDate {
        willSet {
            if newValue != published {
                self.updated = true
            }
        }
    }
    var updatedAt : NSDate? {
        willSet {
            if newValue != updatedAt {
                self.updated = true
            }
        }
    }
    var identifier : String {
        willSet {
            if newValue != identifier {
                self.updated = true
            }
        }
    }
    var content : String {
        willSet {
            if newValue != content {
                self.updated = true
            }
        }
    }
    var read : Bool {
        willSet {
            if newValue != read {
                self.updated = true
            }
        }
    }
    var feed : Feed? {
        willSet {
            if newValue != feed {
                self.updated = true
                if let oldValue = feed where contains(oldValue.articles, self) {
                    oldValue.removeArticle(self)
                }
                if let nv = newValue where !contains(nv.articles, self) {
                    nv.addArticle(self)
                }
            }
        }
    }
    internal private(set) var flags : [String] = []
    internal private(set) var enclosures : [Enclosure] = []

    internal private(set) var updated : Bool = false

    var hashValue : Int {
        if let id = articleID {
            return id.URIRepresentation().hash
        }
        let nonNilHashValues = title.hashValue ^ summary.hashValue ^ author.hashValue ^ published.hash ^ identifier.hashValue ^ content.hashValue & read.hashValue
        let flagsHashValues = flags.reduce(0) { $0 ^ $1.hashValue }
        let possiblyNilHashValues : Int
        if let link = link, updatedAt = updatedAt {
            possiblyNilHashValues = link.hash ^ updatedAt.hash
        } else {
            possiblyNilHashValues = 0
        }
        return nonNilHashValues ^ flagsHashValues ^ possiblyNilHashValues
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
            for enclosure in enclosures {
                enclosure.article = self
            }
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
        published = article.published ?? NSDate()
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

    func addFlag(flag: String) {
        if !contains(self.flags, flag) {
            self.flags.append(flag)
            updated = true
        }
    }

    func removeFlag(flag: String) {
        if contains(self.flags, flag) {
            self.flags = self.flags.filter { $0 != flag }
            updated = true
        }
    }

    func addEnclosure(enclosure: Enclosure) {
        if !contains(self.enclosures, enclosure) {
            self.enclosures.append(enclosure)
            if let otherArticle = enclosure.article {
                otherArticle.removeEnclosure(enclosure)
            }
            enclosure.article = self
            updated = true
        }
    }

    func removeEnclosure(enclosure: Enclosure) {
        if contains(self.enclosures, enclosure) {
            self.enclosures = self.enclosures.filter { $0 != enclosure }
            if enclosure.article == self {
                enclosure.article = nil
            }
            updated = true
        }
    }
}

func ==(a: Article, b: Article) -> Bool {
    if let aID = a.articleID, let bID = b.articleID {
        return aID.URIRepresentation() == bID.URIRepresentation()
    }
    return a.title == b.title && a.link == b.link && a.summary == b.summary && a.author == b.author && a.published == b.published && a.updatedAt == b.updatedAt && a.identifier == b.identifier && a.content == b.content && a.read == b.read && a.flags == b.flags
}