import CoreData

public class DataStoreBackedArray<T>: CollectionType, CustomDebugStringConvertible {
    let entityName: String
    let predicate: NSPredicate?
    let managedObjectContext: NSManagedObjectContext?
    let conversionFunction: ((NSManagedObject) -> T)?
    let sortDescriptors: [NSSortDescriptor]
    private let batchSize = 20

    var internalObjects = [T]()

    private var managedArray = [NSManagedObject]()
    private var appendedObjects: [T] = []

    public typealias Index = Int
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }

    private lazy var internalCount: Int = { self.calculateCount() }()

    public typealias Generator = IndexingGenerator<DataStoreBackedArray>

    public func generate() -> Generator {
        return Generator(self)
    }

    public var count: Int {
        return self.internalCount + self.appendedObjects.count
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

    private var isCoreDataBacked: Bool { return self.managedObjectContext != nil }

    public var isEmpty: Bool { return self.count == 0 }

    public var first: T? {
        if self.isEmpty { return nil }
        return self[0]
    }

    public func filterWithPredicate(predicate: NSPredicate) -> DataStoreBackedArray<T> {
        guard let currentPredicate = self.predicate,
            managedObjectContext = self.managedObjectContext,
            conversionFunction = self.conversionFunction else {
                let array = self.internalObjects.filter {
                    return predicate.evaluateWithObject($0 as? AnyObject)
                }
                return DataStoreBackedArray(array)
        }
        return DataStoreBackedArray(entityName: self.entityName,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [currentPredicate, predicate]),
            managedObjectContext: managedObjectContext,
            conversionFunction: conversionFunction,
            sortDescriptors: self.sortDescriptors)
    }

    public func combineWithPredicate(predicate: NSPredicate) -> DataStoreBackedArray<T> {
        guard let currentPredicate = self.predicate,
            managedObjectContext = self.managedObjectContext,
            conversionFunction = self.conversionFunction else {
                let array = self.internalObjects.filter {
                    return predicate.evaluateWithObject($0 as? AnyObject)
                }
                return DataStoreBackedArray(array)
        }
        return DataStoreBackedArray(entityName: self.entityName,
            predicate: NSCompoundPredicate(orPredicateWithSubpredicates: [currentPredicate, predicate]),
            managedObjectContext: managedObjectContext,
            conversionFunction: conversionFunction,
            sortDescriptors: self.sortDescriptors)
    }

    public func combine(other: DataStoreBackedArray<T>) -> DataStoreBackedArray<T> {
        guard let currentPredicate = self.predicate, otherPredicate = other.predicate,
            managedObjectContext = self.managedObjectContext, conversionFunction = self.conversionFunction
            where other.entityName == self.entityName &&
                other.managedObjectContext == self.managedObjectContext &&
                other.sortDescriptors == self.sortDescriptors else {
                    return DataStoreBackedArray(self.internalObjects + Array(other))
        }

        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [currentPredicate, otherPredicate])

        return DataStoreBackedArray(entityName: self.entityName,
            predicate: predicate,
            managedObjectContext: managedObjectContext,
            conversionFunction: conversionFunction,
            sortDescriptors: self.sortDescriptors)
    }

    public subscript(position: Int) -> T {
        if self.isCoreDataBacked {
            if position < self.internalObjects.count {
                return self.internalObjects[position]
            } else if position >= self.internalCount {
                return self.appendedObjects[position - self.internalCount]
            } else {
                self.fetchUpToPosition(position)
            }
        }
        return self.internalObjects[position]
    }

    public func append(object: T) {
        if !self.isCoreDataBacked {
            self.internalObjects.append(object)
            self.internalCount = self.internalObjects.count
        } else {
            self.appendedObjects.append(object)
        }
    }

    public convenience init() {
        self.init([])
    }

    public init(_ array: [T]) {
        self.internalObjects = array
        self.entityName = ""
        self.predicate = nil
        self.managedObjectContext = nil
        self.conversionFunction = nil
        self.sortDescriptors = []

        self.internalCount = array.count
    }

    public init(entityName: String,
        predicate: NSPredicate,
        managedObjectContext: NSManagedObjectContext,
        conversionFunction: (NSManagedObject) -> T,
        sortDescriptors: [NSSortDescriptor] = []) {
            self.entityName = entityName
            self.predicate = predicate
            self.managedObjectContext = managedObjectContext
            self.conversionFunction = conversionFunction
            self.sortDescriptors = sortDescriptors
            self.internalCount = self.calculateCount()
    }

    private func fetchUpToPosition(position: Int) {
        if self.internalObjects.isEmpty {
            let fetchRequest = NSFetchRequest(entityName: self.entityName)
            fetchRequest.predicate = self.predicate
            fetchRequest.sortDescriptors = self.sortDescriptors
            fetchRequest.fetchBatchSize = self.batchSize
            self.managedObjectContext?.performBlockAndWait {
                let result = try? self.managedObjectContext?.executeFetchRequest(fetchRequest) as? [NSManagedObject]
                guard let array = result else { return }
                self.managedArray = array ?? []
            }
        }
        let start = self.internalObjects.count
        let end = min(self.internalCount, start + ((Int((position - start) / self.batchSize) + 1) * self.batchSize))

        self.managedObjectContext?.performBlockAndWait {
            for i in start..<end {
                self.internalObjects.insert(self.conversionFunction!(self.managedArray[i]), atIndex: i)
            }
            _ = try? self.managedObjectContext?.save()
        }
    }

    private func calculateCount() -> Int {
        var count = 0
        self.managedObjectContext?.performBlockAndWait {
            let fetchRequest = NSFetchRequest(entityName: self.entityName)
            fetchRequest.predicate = self.predicate
            count = self.managedObjectContext!.countForFetchRequest(fetchRequest, error: nil)
        }
        self.internalObjects.reserveCapacity(count)
        return count
    }
}

extension DataStoreBackedArray where T: Equatable {
    public func remove(object: T) -> Bool {
        self.fetchUpToPosition(self.internalCount - 1)
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
        if self.isCoreDataBacked {
            self.managedObjectContext?.performBlockAndWait {
                let managedObject = self.managedArray[idx]
                self.managedObjectContext?.deleteObject(managedObject)
            }
        }
        self.internalObjects.removeAtIndex(idx)
        self.internalCount--

        return true
    }
}

public func ==<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    if left.isCoreDataBacked && right.isCoreDataBacked {
        return left.count == right.count && left.entityName == right.entityName &&
            left.predicate == right.predicate && left.managedObjectContext == right.managedObjectContext &&
            left.sortDescriptors == right.sortDescriptors
    } else {
        return Array(left) == Array(right)
    }
}

public func !=<T: Equatable>(left: DataStoreBackedArray<T>, right: DataStoreBackedArray<T>) -> Bool {
    return !(left == right)
}
