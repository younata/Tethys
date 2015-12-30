
import CoreData

public struct CoreDataBackedGenerator<T>: GeneratorType {
    public typealias Element = T
    private var currentIndex: Int = 0

    private let array: CoreDataBackedArray<T>

    private init(array: CoreDataBackedArray<T>) {
        self.array = array
    }

    mutating public func next() -> Element? {
        if self.currentIndex == self.array.count {
            return nil
        }
        let object = self.array[currentIndex]
        self.currentIndex++
        return object
    }
}

public class CoreDataBackedArray<T>: CollectionType, CustomDebugStringConvertible {
    private let entityName: String
    private let predicate: NSPredicate?
    private let managedObjectContext: NSManagedObjectContext?
    private let conversionFunction: ((NSManagedObject) -> T)?
    private let sortDescriptors: [NSSortDescriptor]
    private let batchSize = 25

    var internalObjects = [T]()

    private var managedArray = [NSManagedObject]()
    private var appendedObjects: [T] = []

    public typealias Index = Int
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }

    public typealias Generator = CoreDataBackedGenerator<T>

    private lazy var internalCount: Int = {
        return self.calculateCount()
    }()

    public var count: Int {
        return self.internalCount + self.appendedObjects.count
    }

    public var debugDescription: String {
        var ret = "[ "
        for (idx, object) in self.enumerate() {
            let reflection = Mirror(reflecting: object)
            ret += reflection.description
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

    public func filter(@noescape includeElement: (Generator.Element) throws -> Bool) rethrows -> [Generator.Element] {
        var ret: [T] = []
        for element in self {
            do {
                if try includeElement(element) {
                    ret.append(element)
                }
            } catch {}
        }
        return ret
    }

    public subscript(position: Int) -> T {
        assert(position < count, "Array index out of range")
        if self.isCoreDataBacked {
            if position < self.internalObjects.count {
                return self.internalObjects[position]
            } else if position >= self.internalCount {
                return self.appendedObjects[position - self.internalCount]
            } else {
                self.fetchUpToPosition(position, wait: true)
            }
        }
        return self.internalObjects[position]
    }

    public func generate() -> Generator {
        return CoreDataBackedGenerator<T>(array: self)
    }

    public func append(object: T) {
        if !self.isCoreDataBacked {
            self.internalObjects.append(object)
            self.internalCount = self.internalObjects.count
        } else {
            self.appendedObjects.append(object)
        }
    }

    init(array: [T]) {
        self.internalObjects = array
        self.entityName = ""
        self.predicate = nil
        self.managedObjectContext = nil
        self.conversionFunction = nil
        self.sortDescriptors = []

        self.internalCount = array.count
    }

    public init(entityName: String, predicate: NSPredicate, managedObjectContext: NSManagedObjectContext, conversionFunction: (NSManagedObject) -> T, sortDescriptors: [NSSortDescriptor] = []) {
        self.entityName = entityName
        self.predicate = predicate
        self.managedObjectContext = managedObjectContext
        self.conversionFunction = conversionFunction
        self.sortDescriptors = sortDescriptors
    }

    private func fetchUpToPosition(position: Int, wait: Bool = false) {
        if self.internalObjects.isEmpty {
            let fetchRequest = NSFetchRequest(entityName: self.entityName)
            fetchRequest.predicate = self.predicate
            fetchRequest.sortDescriptors = self.sortDescriptors
            fetchRequest.fetchBatchSize = self.batchSize
            self.managedObjectContext?.performBlockAndWait {
                guard let array = try? self.managedObjectContext?.executeFetchRequest(fetchRequest) as? [NSManagedObject] else { return }
                self.managedArray = array ?? []
            }
        }
        let start = self.internalObjects.count
        let end = min(self.internalCount, start + ((Int((position - start) / self.batchSize) + 1) * self.batchSize))

        let block: (Void) -> Void = {
            for i in start..<end {
                self.internalObjects.append(self.conversionFunction!(self.managedArray[i]))
            }
        }

        if wait {
            self.managedObjectContext?.performBlockAndWait(block)
        } else {
            self.managedObjectContext?.performBlock(block)
        }
    }

    private func calculateCount() -> Int {
        var count = 0
        self.managedObjectContext?.performBlockAndWait {
            let fetchRequest = NSFetchRequest(entityName: self.entityName)
            fetchRequest.predicate = self.predicate
            count = self.managedObjectContext!.countForFetchRequest(fetchRequest, error: nil)
        }
        return count
    }
}

extension CoreDataBackedArray where T: Equatable {
    func remove(object: T) -> Bool {
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

public func ==<T: Equatable>(a: CoreDataBackedArray<T>, b: CoreDataBackedArray<T>) -> Bool {
    if a.isCoreDataBacked && b.isCoreDataBacked {
        return a.count == b.count && a.entityName == b.entityName &&
            a.predicate == b.predicate && a.managedObjectContext == b.managedObjectContext &&
            a.sortDescriptors == b.sortDescriptors
    } else {
        return Array(a) == Array(b)
    }
}
