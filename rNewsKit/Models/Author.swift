import Foundation

@objc public final class Author: NSObject {
    public internal(set) var name: String {
        willSet {
            if newValue != name {
                updated = true
            }
        }
    }

    public internal(set) var email: URL? {
        willSet {
            if newValue != email {
                updated = true
            }
        }
    }

    internal private(set) var updated: Bool = false
    internal private(set) var authorID: String? = nil

    public var identifier: String {
        return self.authorID ?? self.name
    }

    @objc private var id: String { return self.identifier }

    public convenience init(_ name: String, email: URL? = nil) {
        self.init(name: name, email: email)
    }

    public init(name: String, email: URL?) {
        self.name = name
        self.email = email

        super.init()
    }

    public override var hashValue: Int {
        return self.name.hash ^ (self.email?.hashValue ?? 0)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Author else { return false }
        return other.name == self.name && other.email == self.email
    }

    public override var description: String {
        if let emailURL = self.email, let email = (emailURL as NSURL).resourceSpecifier {
            return "\(self.name) <\(email)>"
        }
        return self.name
    }

    internal init(realmAuthor author: RealmAuthor) {
        self.name = author.name
        let email: URL?
        if let emailString = author.email {
            email = URL(string: emailString)
        } else {
            email = nil
        }
        self.email = email
        self.authorID = author.id
        super.init()
    }
}
