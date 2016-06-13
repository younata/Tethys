import CoreData
import RealmSwift
import Result
import CBGPromise

private enum BackingStore: Equatable {
    case CoreData(CoreDataFetchResultsController)
    case Realm(RealmFetchResultsController)
    case Array
}

private func == (lhs: BackingStore, rhs: BackingStore) -> Bool {
    switch (lhs, rhs) {
    case (.CoreData(_), .CoreData(_)):
        return true
    case (.Realm(_), .Realm(_)):
        return true
    case (.Array, .Array):
        return true
    default:
        return false
    }
}

public final class DataStoreBackedArray<T where T: AnyObject, T: Equatable>: CollectionType, CustomDebugStringConvertible {
    private let coreDataFetchResults: CoreDataFetchResultsController?
    let coreDataConversionFunction: ((NSManagedObject) -> T)?

    private let realmFetchResults: RealmFetchResultsController?
    let realmConversionFunction: ((Object) -> T)?

    private var internalObjects: [T] = []
    private var _appendedObjects: [T] = []
    private var appendedObjects: [T] {
        get {
            self.cleanAppendedItems()
            return self._appendedObjects
        }
        set {
            self._appendedObjects = newValue
        }
    }

    public typealias Index = Int
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }

    public typealias Generator = IndexingGenerator<DataStoreBackedArray>

    public func generate() -> Generator {
        return Generator(self)
    }

    public var count: Int {
        self.cleanAppendedItems()
        let count: Int
        if let fetchResults = self.coreDataFetchResults {
            count = fetchResults.count
        } else if let fetchResults = self.realmFetchResults {
            count = fetchResults.count
        } else {
            count = self.internalObjects.count
        }
        return count + self.appendedObjects.count
    }

    public var debugDescription: String {
        return Array(self).debugDescription
    }

    private var backingStore: BackingStore {
        if let fetchResults = self.coreDataFetchResults {
            return .CoreData(fetchResults)
        }
        if let fetchResults = self.realmFetchResults {
            return .Realm(fetchResults)
        }
        return .Array
    }

    public var isEmpty: Bool { return self.count == 0 }

    public var first: T? {
        if self.isEmpty { return nil }
        return self[0]
    }

    public func filterWithPredicate(predicate: NSPredicate) -> DataStoreBackedArray<T> {
        let filterArray: Void -> DataStoreBackedArray = {
            let array = self.internalObjects.filter {
                return predicate.evaluateWithObject($0)
            }
            return DataStoreBackedArray(array)
        }

        switch self.backingStore {
        case .Array:
            return filterArray()
        case let .CoreData(fetchResults):
            // swiftlint:disable force_try
            return DataStoreBackedArray(coreDataFetchResultsController: fetchResults.filter(predicate),
                                        conversionFunction: self.coreDataConversionFunction!)
        case let .Realm(fetchResults):
            return DataStoreBackedArray(realmFetchResultsController: fetchResults.filter(predicate),
                                        conversionFunction: self.realmConversionFunction!)
            // swiftlint:enable force_try
        }
    }

    public func combine(other: DataStoreBackedArray<T>) -> DataStoreBackedArray<T> {
        let combineArray: Void -> DataStoreBackedArray<T> = {
            return DataStoreBackedArray(self.internalObjects + Array(other))
        }

        guard self.backingStore == other.backingStore else { return combineArray() }

        switch self.backingStore {
        case .Array:
            return combineArray()
        case let .CoreData(fetchResults):
            // swiftlint:disable force_try
            return DataStoreBackedArray(coreDataFetchResultsController: fetchResults.combine(other.coreDataFetchResults!),
                                        conversionFunction: self.coreDataConversionFunction!)
        case let .Realm(fetchResults):
            return DataStoreBackedArray(realmFetchResultsController: fetchResults.combine(other.realmFetchResults!),
                                        conversionFunction: self.realmConversionFunction!)
            // swiftlint:enable force_try
        }

    }

    public subscript(position: Int) -> T {
        switch self.backingStore {
        case let .CoreData(fetchResults):
            // swiftlint:disable force_try
            if position < fetchResults.count {
                return self.coreDataConversionFunction!(fetchResults[position])
            }
            return self.appendedObjects[position - fetchResults.count]
        case let .Realm(fetchResults):
            if position < fetchResults.count {
                return self.realmConversionFunction!(fetchResults[position])
            }
            return self.appendedObjects[position - fetchResults.count]
            // swiftlint:enabled force_try
        case .Array:
            return self.internalObjects[position]
        }
    }

    public func append(object: T) {
        switch self.backingStore {
        case .CoreData, .Realm:
            self.appendedObjects.append(object)
        case .Array:
            self.internalObjects.append(object)
        }
    }

    public convenience init() {
        self.init([])
    }

    public init(_ array: [T]) {
        self.internalObjects = array

        self.coreDataFetchResults = nil
        self.coreDataConversionFunction = nil

        self.realmFetchResults = nil
        self.realmConversionFunction = nil
    }

    init(realmFetchResultsController: RealmFetchResultsController, conversionFunction: Object -> T) {
        self.realmFetchResults = realmFetchResultsController
        self.realmConversionFunction = conversionFunction

        self.coreDataFetchResults = nil
        self.coreDataConversionFunction = nil
    }

    init(coreDataFetchResultsController: CoreDataFetchResultsController, conversionFunction: NSManagedObject -> T) {
        self.coreDataFetchResults = coreDataFetchResultsController
        self.coreDataConversionFunction = conversionFunction

        self.realmFetchResults = nil
        self.realmConversionFunction = nil
    }

    deinit {
        self.internalObjects = []
        self.appendedObjects = []
    }

    private func cleanAppendedItems() {
        switch self.backingStore {
        case let .CoreData(fetchResults):
            for (idx, item) in self._appendedObjects.enumerate() {
                for fetchIndex in 0..<fetchResults.count {
                    if self.coreDataConversionFunction!(fetchResults[fetchIndex]) == item {
                        self._appendedObjects.removeAtIndex(idx)
                    }
                }
            }
        case let .Realm(fetchResults):
            for (idx, item) in self._appendedObjects.enumerate() {
                for fetchIndex in 0..<fetchResults.count {
                    if self.realmConversionFunction!(fetchResults[fetchIndex]) == item {
                        self._appendedObjects.removeAtIndex(idx)
                    }
                }
            }
        default:
            return
        }
    }

    public func remove(object: T) -> Future<Bool> {
        let promise = Promise<Bool>()

        if let index = self.appendedObjects.indexOf(object) {
            self.appendedObjects.removeAtIndex(index)
            promise.resolve(true)
            return promise.future
        }

        switch self.backingStore {
        case let .CoreData(fetchResults):
            if let index = self.indexOf(object) {
                do {
                    try fetchResults.delete(index)
                    promise.resolve(true)
                } catch {
                    promise.resolve(false)
                }
            } else {
                promise.resolve(false)
            }
        case let .Realm(fetchResults):
            if let index = self.indexOf(object) {
                do {
                    try fetchResults.delete(index)
                    promise.resolve(true)
                } catch {
                    promise.resolve(false)
                }
            } else {
                promise.resolve(false)
            }
        case .Array:
            if let index = self.internalObjects.indexOf(object) {
                self.internalObjects.removeAtIndex(index)
                promise.resolve(true)
            } else {
                promise.resolve(false)
            }
            break
        }

        if promise.future.value == nil {
            promise.resolve(false)
        }
        return promise.future
    }
}

public func ==<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    switch (left.backingStore, right.backingStore) {
    case (let .CoreData(leftFetchResults), let .CoreData(rightFetchResults)):
        return leftFetchResults == rightFetchResults
    case (let .Realm(leftFetchResults), let .Realm(rightFetchResults)):
        return leftFetchResults == rightFetchResults
    default:
        return Array(left) == Array(right)
    }
}

public func !=<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    return !(left == right)
}
