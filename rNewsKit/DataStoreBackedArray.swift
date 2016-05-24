import CoreData
import RealmSwift
import Result
import CBGPromise

private enum BackingStore {
    case CoreData
    case Realm
    case Array
}

public final class DataStoreBackedArray<T: AnyObject>: CollectionType, CustomDebugStringConvertible {
    let predicate: NSPredicate?
    let sortDescriptors: [NSSortDescriptor]

    let entityName: String
    let managedObjectContext: NSManagedObjectContext?
    let coreDataConversionFunction: ((NSManagedObject) -> T)?
    private var managedArray = [NSManagedObject]()

    let realmDataType: Object.Type?
    let realmConfiguration: Realm.Configuration?
    var realm: Realm? {
        if let configuration = self.realmConfiguration {
            return try? Realm(configuration: configuration)
        }
        return nil
    }
    let realmConversionFunction: ((Object) -> T)?

    private let batchSize = 50

    var internalObjects = [T]()

    public var loadedCount: Int {
        return self.internalObjects.count + self.appendedObjects.count
    }

    private var appendedObjects: [T] = []

    public typealias Index = Int
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }

    private var _internalCount: Int? = nil
    private let internalCountPromise = Promise<Int>()
    private var internalCount: Future<Int> {
        get {
            if let count = self._internalCount {
                let promise = Promise<Int>()
                promise.resolve(count)
                return promise.future
            } else {
                return self.calculateCount()
            }
        }
    }

    public typealias Generator = IndexingGenerator<DataStoreBackedArray>

    public func generate() -> Generator {
        return Generator(self)
    }

    public var count: Int {
        return self.internalCount.wait()! + self.appendedObjects.count
    }

    public var debugDescription: String {
        var ret = "[ "
        for (idx, object) in self.enumerate() {
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

    private var backingStore: BackingStore {
        if self.managedObjectContext != nil { return .CoreData }
        if self.realmConfiguration != nil { return .Realm }
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

        let currentPredicate = self.predicate ?? NSPredicate(value: true)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [currentPredicate, predicate])

        switch self.backingStore {
        case .Array:
            return filterArray()
        case .CoreData:
            guard let managedObjectContext = self.managedObjectContext,
                conversionFunction = self.coreDataConversionFunction else {
                    return filterArray()
            }
            return DataStoreBackedArray(entityName: self.entityName,
                predicate: compoundPredicate,
                managedObjectContext: managedObjectContext,
                conversionFunction: conversionFunction,
                sortDescriptors: self.sortDescriptors)
        case .Realm:
            guard let realmDataType = self.realmDataType,
                realmConfiguration = self.realmConfiguration,
                conversionFunction = self.realmConversionFunction else {
                    return filterArray()
            }
            return DataStoreBackedArray(realmDataType: realmDataType,
                predicate: compoundPredicate,
                realmConfiguration: realmConfiguration,
                conversionFunction: conversionFunction,
                sortDescriptors: self.sortDescriptors)
        }
    }

    public func combine(other: DataStoreBackedArray<T>) -> DataStoreBackedArray<T> {
        let combineArray: Void -> DataStoreBackedArray<T> = {
            return DataStoreBackedArray(self.internalObjects + Array(other))
        }

        let currentPredicate = self.predicate ?? NSPredicate(value: true)
        let otherPredicate = other.predicate ?? NSPredicate(value: true)
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [currentPredicate, otherPredicate])

        guard self.backingStore == other.backingStore else { return combineArray() }

        switch self.backingStore {
        case .Array:
            return combineArray()
        case .CoreData:
            guard let managedObjectContext = self.managedObjectContext,
                conversionFunction = self.coreDataConversionFunction
                where other.entityName == self.entityName &&
                    other.managedObjectContext == self.managedObjectContext &&
                    other.sortDescriptors == self.sortDescriptors else {
                        return combineArray()
            }

            return DataStoreBackedArray(entityName: self.entityName,
                predicate: compoundPredicate,
                managedObjectContext: managedObjectContext,
                conversionFunction: conversionFunction,
                sortDescriptors: self.sortDescriptors)
        case .Realm:
            guard let realmConfiguration = self.realmConfiguration, dataType = self.realmDataType,
                conversionFunction = self.realmConversionFunction where self.realmDataType == other.realmDataType &&
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
        if self.backingStore != .Array {
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

    public func append(object: T) {
        switch self.backingStore {
        case .CoreData, .Realm:
            self.appendedObjects.append(object)
        case .Array:
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

        self.entityName = ""
        self.managedObjectContext = nil
        self.coreDataConversionFunction = nil

        self._internalCount = array.count
    }

    public init(realmDataType: Object.Type,
        predicate: NSPredicate,
        realmConfiguration: Realm.Configuration,
        conversionFunction: Object -> T,
        sortDescriptors: [NSSortDescriptor] = []) {
            self.predicate = predicate
            self.sortDescriptors = sortDescriptors

            self.realmDataType = realmDataType
            self.realmConfiguration = realmConfiguration
            self.realmConversionFunction = conversionFunction

            self.entityName = ""
            self.managedObjectContext = nil
            self.coreDataConversionFunction = nil
    }

    public init(entityName: String,
        predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        conversionFunction: NSManagedObject -> T,
        sortDescriptors: [NSSortDescriptor] = []) {
            self.predicate = predicate
            self.sortDescriptors = sortDescriptors

            self.realmDataType = nil
            self.realmConfiguration = nil
            self.realmConversionFunction = nil

            self.entityName = entityName
            self.managedObjectContext = managedObjectContext
            self.coreDataConversionFunction = conversionFunction
            self.calculateCount().then { self._internalCount = $0 }
    }

    deinit {
        self.internalObjects = []
        self.appendedObjects = []
        self.managedArray = []
    }

    private func fetchUpToPosition(position: Int) {
        autoreleasepool {
            if self.backingStore == .CoreData {
                if self.internalObjects.isEmpty {
                    let fetchRequest = NSFetchRequest(entityName: self.entityName)
                    fetchRequest.predicate = self.predicate
                    fetchRequest.sortDescriptors = self.sortDescriptors
                    fetchRequest.fetchBatchSize = self.batchSize
                    self.managedObjectContext?.performBlockAndWait {
                        let result = try? self.managedObjectContext?.executeFetchRequest(fetchRequest)
                            as? [NSManagedObject]
                        guard let array = result else { return }
                        self.managedArray = array ?? []
                    }
                }
                let start = self.internalObjects.count
                self.internalCount.wait()
                let internalCount = self.internalCount.value!
                let end = min(internalCount,
                              start + ((Int((position - start) / self.batchSize) + 1) * self.batchSize))

                self.managedObjectContext?.performBlockAndWait {
                    for i in start..<end {
                        self.internalObjects.insert(self.coreDataConversionFunction!(self.managedArray[i]), atIndex: i)
                    }
                    _ = try? self.managedObjectContext?.save()
                }
            } else if let objects = self.realmObjectList() {
                let start = self.internalObjects.count
                let end = min(objects.count,
                              start + ((Int((position - start) / self.batchSize) + 1) * self.batchSize))

                for i in start..<end {
                    self.internalObjects.insert(self.realmConversionFunction!(objects[i]), atIndex: i)
                }
            }
        }
    }

    private func calculateCount() -> Future<Int> {
        let promise = Promise<Int>()
        let loadedObjects = self.internalObjects.count
        if loadedObjects != 0 {
            promise.resolve(loadedObjects)
        }
        autoreleasepool {
            if self.backingStore == .CoreData {
                var count = 0
                self.managedObjectContext?.performBlockAndWait {
                    let fetchRequest = NSFetchRequest(entityName: self.entityName)
                    fetchRequest.predicate = self.predicate
                    count = self.managedObjectContext!.countForFetchRequest(fetchRequest, error: nil)
                }
                self.internalObjects.reserveCapacity(count)
                promise.resolve(count)
            } else if let list = self.realmObjectList() {
                promise.resolve(list.count)
            }
        }
        return promise.future
    }

    private func realmObjectList() -> Results<Object>? {
        guard self.backingStore == .Realm, let dataType = self.realmDataType, realm = self.realm else { return nil }
        let predicate = self.predicate ?? NSPredicate(value: true)
        let sortDescriptors: [SortDescriptor] = self.sortDescriptors.flatMap {
            if let key = $0.key {
                return SortDescriptor(property: key, ascending: $0.ascending)
            }
            return nil
        }
        let results = realm.objects(dataType).filter(predicate).sorted(sortDescriptors)
        self._internalCount = results.count
        return results
    }
}

extension DataStoreBackedArray where T: Equatable {
    public func remove(object: T) -> Future<Bool> {
        return self.internalCount.map { (internalCount: Int) -> Bool in
            self.fetchUpToPosition(internalCount - 1)
            var idxToRemove: Int? = nil
            for (idx, obj) in self.appendedObjects.enumerate() {
                if obj == object {
                    idxToRemove = idx
                    break
                }
            }
            if let _ = idxToRemove {
                self.appendedObjects = self.appendedObjects.filter { $0 != object }
                return true
            }
            for (idx, obj) in self.enumerate() {
                if obj == object {
                    idxToRemove = idx
                    break
                }
            }
            guard let idx = idxToRemove else {
                return false
            }
            autoreleasepool {
                if self.backingStore == .CoreData {
                    self.managedObjectContext?.performBlockAndWait {
                        let managedObject = self.managedArray[idx]
                        self.managedObjectContext?.deleteObject(managedObject)
                    }
                } else if let objects = self.realmObjectList() {
                    self.realm?.beginWrite()
                    self.realm?.delete(objects[idx])
                    _ = try? self.realm?.commitWrite()
                }
            }
            self.internalObjects.removeAtIndex(idx)
            self._internalCount! -= 1
            
            return true
        }
    }
}

public func ==<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    if left.backingStore == right.backingStore {
        return left.count == right.count && left.entityName == right.entityName &&
            left.realmDataType == right.realmDataType && left.predicate == right.predicate &&
            left.managedObjectContext == right.managedObjectContext && left.realm == right.realm &&
            left.sortDescriptors == right.sortDescriptors
    } else {
        return Array(left) == Array(right)
    }
}

public func !=<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    return !(left == right)
}
