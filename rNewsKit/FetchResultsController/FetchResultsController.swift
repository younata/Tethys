import Foundation

public protocol FetchResultsController {
    associatedtype Element

    var count: Int { get }
    var predicate: NSPredicate { get }

    func get(index: Int) throws -> Element
    mutating func insert(item: Element) throws
    mutating func delete(index: Int) throws
    func replacePredicate(predicate: NSPredicate) -> Self
}

extension FetchResultsController {
    subscript(index: Int) -> Element {
        // swiftlint:disable force_try
        return try! self.get(index)
        // swiftlint:enable force_try
    }

    func filter(predicate: NSPredicate) -> Self {
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [self.predicate, predicate])
        return self.replacePredicate(compoundPredicate)
    }

    func combine(fetchResultsController: Self) -> Self {
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [self.predicate,
            fetchResultsController.predicate])
        return self.replacePredicate(compoundPredicate)
    }
}

public struct AnyFetchResultsController<T>: FetchResultsController {
    public typealias Element = T

    private let _count: () -> Int
    private let _predicate: () -> NSPredicate

    private let _get: Int throws -> T
    private let _insert: T throws -> ()
    private let _delete: Int throws -> ()
    private let _replacePredicate: NSPredicate -> AnyFetchResultsController<T>

    public init<Base: FetchResultsController where Base.Element == T>(base: Base) {
        self._count = { base.count }
        self._predicate = { base.predicate }
        self._get = base.get
        var _base = base
        self._insert = { (item: T) throws in
            return try _base.insert(item)
        }
        self._delete = { (index: Int) throws in
            return try _base.delete(index)
        }
        self._replacePredicate = { predicate in
            return AnyFetchResultsController(base: base.replacePredicate(predicate))
        }
    }

    public var count: Int { return self._count() }
    public var predicate: NSPredicate { return self._predicate() }
    public func get(index: Int) throws -> T { return try self._get(index) }
    mutating public func insert(item: T) throws { return try self._insert(item) }
    mutating public func delete(index: Int) throws { return try self._delete(index) }

    public func replacePredicate(predicate: NSPredicate) -> AnyFetchResultsController<T> {
        return self._replacePredicate(predicate)
    }
}
