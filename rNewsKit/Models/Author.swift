import Foundation
import JavaScriptCore

@objc public protocol AuthorJSExport: JSExport {
    var name: String { get }
    var email: NSURL? { get }
}

@objc public final class Author: NSObject, AuthorJSExport {
    dynamic public internal(set) var name: String {
        willSet {
            if newValue != name {
                updated = true
            }
        }
    }

    dynamic public internal(set) var email: NSURL? {
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

    public convenience init(_ name: String, email: NSURL? = nil) {
        self.init(name: name, email: email)
    }

    public init(name: String, email: NSURL?) {
        self.name = name
        self.email = email

        super.init()
    }

    public override var hashValue: Int {
        return self.name.hash ^ (self.email?.hash ?? 0)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let other = object as? Author else { return false }
        return other.name == self.name && other.email == self.email
    }

    public override var description: String {
        if let email = self.email?.resourceSpecifier where !email.isEmpty {
            return "\(self.name) <\(email)>"
        }
        return self.name
    }

    internal init(realmAuthor author: RealmAuthor) {
        self.name = author.name
        let email: NSURL?
        if let emailString = author.email {
            email = NSURL(string: emailString)
        } else {
            email = nil
        }
        self.email = email
        self.authorID = author.id
        super.init()
    }
}
