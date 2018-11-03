import RealmSwift
import Result
import CBGPromise

fileprivate enum BackingStore {
    case realm
    case array
}

public final class DataStoreBackedArray<T: AnyObject>: Collection, CustomDebugStringConvertible {
    let predicate: NSPredicate?
    let sortDescriptors: [NSSortDescriptor]

    let realmDataType: Object.Type?
    let realmConfiguration: Realm.Configuration?
    var realm: Realm? {
        if let configuration = self.realmConfiguration {
            return try? Realm(configuration: configuration)
        }
        return nil
    }
    let realmConversionFunction: ((Object) -> T)?

    fileprivate let batchSize = 50

    var internalObjects = [T]()

    public var loadedCount: Int {
        return self.internalObjects.count + self.appendedObjects.count
    }

    fileprivate var appendedObjects: [T] = []

    public typealias Index = Int
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }

    fileprivate var _internalCount: Int?
    fileprivate let internalCountPromise = Promise<Int>()
    fileprivate var internalCount: Future<Int> {
        if let count = self._internalCount {
            let promise = Promise<Int>()
            promise.resolve(count)
            return promise.future
        } else {
            return self.calculateCount()
        }
    }

    public typealias Iterator = IndexingIterator<DataStoreBackedArray>

    public func makeIterator() -> Iterator {
        return Iterator(_elements: self)
    }

    public var count: Int {
        return self.internalCount.wait()! + self.appendedObjects.count
    }

    public var debugDescription: String {
        var ret = "[ "
        for (idx, object) in self.enumerated() {
            let description: String
            if let describable = object as? CustomDebugStringConvertible {
                description = describable.debugDescription
            } else {
                let reflection = Mirror(reflecting: object)
                description = reflection.description
            }
            ret += description
            if idx < (self.count - 1) {
                ret += ", "
            }
        }
        return ret + " ]"
    }

    fileprivate var backingStore: BackingStore {
        if self.realmConfiguration != nil { return .realm }
        return .array
    }

    public var isEmpty: Bool { return self.count == 0 }

    public var first: T? {
        if self.isEmpty { return nil }
        return self[0]
    }
    public var last: T? {
        if self.isEmpty { return nil }
        return self[self.count - 1]
    }

    public func array() -> Future<[T]> {
        return self.internalCount.map { count -> [T] in
            var objects = [T]()
            for i in 0..<count {
                objects.append(self[i])
            }
            return objects + self.appendedObjects
        }
    }

    public func filterWithPredicate(_ predicate: NSPredicate) -> DataStoreBackedArray<T> {
        let filterArray: (Void) -> DataStoreBackedArray = {
            let array = self.internalObjects.filter {
                return predicate.evaluate(with: $0)
            }
            return DataStoreBackedArray(array)
        }

        let currentPredicate = self.predicate ?? NSPredicate(value: true)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [currentPredicate, predicate])

        switch self.backingStore {
        case .array:
            return filterArray()
        case .realm:
            guard let realmDataType = self.realmDataType,
                let realmConfiguration = self.realmConfiguration,
                let conversionFunction = self.realmConversionFunction else {
                    return filterArray()
            }
            return DataStoreBackedArray(realmDataType: realmDataType,
                predicate: compoundPredicate,
                realmConfiguration: realmConfiguration,
                conversionFunction: conversionFunction,
                sortDescriptors: self.sortDescriptors)
        }
    }

    public func combine(_ other: DataStoreBackedArray<T>) -> DataStoreBackedArray<T> {
        let combineArray: (Void) -> DataStoreBackedArray<T> = {
            return DataStoreBackedArray(self.internalObjects + Array(other))
        }

        let currentPredicate = self.predicate ?? NSPredicate(value: true)
        let otherPredicate = other.predicate ?? NSPredicate(value: true)
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [currentPredicate, otherPredicate])

        guard self.backingStore == other.backingStore else { return combineArray() }

        switch self.backingStore {
        case .array:
            return combineArray()
        case .realm:
            guard let realmConfiguration = self.realmConfiguration, let dataType = self.realmDataType,
                let conversionFunction = self.realmConversionFunction, self.realmDataType == other.realmDataType &&
                    other.sortDescriptors == self.sortDescriptors else {
                        return combineArray()
            }

            return DataStoreBackedArray(realmDataType: dataType,
                predicate: compoundPredicate,
                realmConfiguration: realmConfiguration,
                conversionFunction: conversionFunction,
                sortDescriptors: self.sortDescriptors)
        }

    }

    public subscript(position: Int) -> T {
        let internalCount = self.internalCount.wait()!
        if self.backingStore != .array {
            if position < self.internalObjects.count {
                return self.internalObjects[position]
            } else if position >= internalCount {
                return self.appendedObjects[position - internalCount]
            } else {
                self.fetchUpToPosition(position)
            }
        }
        return self.internalObjects[position]
    }

    public func index(after i: Int) -> Int {
        return (i + 1)
    }

    public func append(_ object: T) {
        switch self.backingStore {
        case .realm:
            self.appendedObjects.append(object)
        case .array:
            self.internalObjects.append(object)
            self._internalCount = self.internalObjects.count
        }
    }

    public convenience init() {
        self.init([])
    }

    public init(_ array: [T]) {
        self.internalObjects = array
        self.predicate = nil
        self.sortDescriptors = []

        self.realmDataType = nil
        self.realmConfiguration = nil
        self.realmConversionFunction = nil

        self._internalCount = array.count
    }

    public init(realmDataType: Object.Type,
                predicate: NSPredicate,
                realmConfiguration: Realm.Configuration,
                conversionFunction: @escaping (Object) -> T,
                sortDescriptors: [NSSortDescriptor] = []) {
        self.predicate = predicate
        self.sortDescriptors = sortDescriptors

        self.realmDataType = realmDataType
        self.realmConfiguration = realmConfiguration
        self.realmConversionFunction = conversionFunction
    }

    deinit {
        self.internalObjects = []
        self.appendedObjects = []
    }

    fileprivate func fetchUpToPosition(_ position: Int) {
        func wtfswift3min<T: Comparable>(_ x: T, _ y: T) -> T {
            if x < y { return x }
            return y
        }
        autoreleasepool {
            if let objects = self.realmObjectList() {
                let start = self.internalObjects.count
                let end = wtfswift3min(objects.count,
                              start + ((Int((position - start) / self.batchSize) + 1) * self.batchSize))

                for i in start..<end {
                    self.internalObjects.insert(self.realmConversionFunction!(objects[i]), at: i)
                }
            }
        }
    }

    fileprivate func calculateCount() -> Future<Int> {
        let promise = Promise<Int>()
        let loadedObjects = self.internalObjects.count
        if loadedObjects != 0 {
            promise.resolve(loadedObjects)
        }
        autoreleasepool {
            if let list = self.realmObjectList() {
                promise.resolve(list.count)
            }
        }
        return promise.future
    }

    fileprivate func realmObjectList() -> Results<Object>? {
        guard self.backingStore == .realm, let dataType = self.realmDataType, let realm = self.realm else { return nil }
        let predicate = self.predicate ?? NSPredicate(value: true)
        let sortDescriptors: [SortDescriptor] = self.sortDescriptors.flatMap {
            if let key = $0.key {
                return SortDescriptor(keyPath: key, ascending: $0.ascending)
            }
            return nil
        }
        let results: Results<Object>
        if sortDescriptors.isEmpty {
            results = realm.objects(dataType).filter(predicate)
        } else {
            results = realm.objects(dataType).filter(predicate).sorted(by: sortDescriptors)
        }
        self._internalCount = results.count
        return results
    }
}

extension DataStoreBackedArray where T: Equatable {
    public func remove(_ object: T) -> Future<Bool> {
        return self.internalCount.map { (internalCount: Int) -> Bool in
            self.fetchUpToPosition(internalCount - 1)
            var idxToRemove: Int? = nil
            for (idx, obj) in self.appendedObjects.enumerated() {
                if obj == object {
                    idxToRemove = idx
                    break
                }
            }
            if let _ = idxToRemove {
                self.appendedObjects = self.appendedObjects.filter { $0 != object }
                return true
            }
            for (idx, obj) in self.enumerated() {
                if obj == object {
                    idxToRemove = idx
                    break
                }
            }
            guard let idx = idxToRemove else {
                return false
            }
            autoreleasepool {
                if let objects = self.realmObjectList() {
                    self.realm?.beginWrite()
                    self.realm?.delete(objects[idx])
                    _ = try? self.realm?.commitWrite()
                }
            }
            self.internalObjects.remove(at: idx)
            self._internalCount! -= 1
            return true
        }
    }
}

public func ==<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    if left.backingStore == right.backingStore {
        return left.count == right.count && left.realmDataType == right.realmDataType &&
            left.predicate == right.predicate && left.realm == right.realm &&
            left.sortDescriptors == right.sortDescriptors
    } else {
        return Array(left) == Array(right)
    }
}

public func !=<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    return !(left == right)
}
