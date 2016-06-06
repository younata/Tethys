public protocol FetchResultsController {
    associatedtype Element

    var count: Int { get }

    func get(index: Int) throws -> Element
    mutating func insert(item: Element) throws
    mutating func delete(index: Int) throws
}

extension FetchResultsController {
    subscript(index: Int) -> Element {
        // swiftlint:disable force_try
        return try! self.get(index)
        // swiftlint:enable force_try
    }
}
