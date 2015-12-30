import CoreData

public struct CoreDataBackedGenerator<T>: GeneratorType {
    public typealias Element = T
    private var currentIndex: Int = 0

    private let array: CoreDataBackedArray<T>

    private init(array: CoreDataBackedArray<T>) {
        self.array = array
    }

    mutating public func next() -> Element? {
        if currentIndex + 1 == array.count {
            return nil
        }
        let object = array[currentIndex]
        currentIndex++
        return object
    }
}

public class CoreDataBackedArray<T>: CollectionType {
    private let entityName: String
    private let predicate: NSPredicate
    private let managedObjectContext: NSManagedObjectContext
    private let conversionFunction: (NSManagedObject) -> T
    private let sortDescriptors: [NSSortDescriptor]
    private let batchSize = 25

    var internalObjects = [T]()

    private var managedArray = [NSManagedObject]()

    public typealias Index = Int
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }

    public typealias Generator = CoreDataBackedGenerator<T>

    public private(set) lazy var count: Int = {
        var count = 0
        self.managedObjectContext.performBlockAndWait {
            let fetchRequest = NSFetchRequest(entityName: self.entityName)
            fetchRequest.predicate = self.predicate
            count = self.managedObjectContext.countForFetchRequest(fetchRequest, error: nil)
        }
        return count
    }()

    public var isEmpty: Bool { return self.count == 0 }

    public var first: T? {
        if self.isEmpty { return nil }
        return self[0]
    }

    public subscript(position: Int) -> T {
        assert(position < count, "Array index out of range")
        if position < internalObjects.count {
            return internalObjects[position]
        } else {
            self.fetchUpToPosition(position, wait: true)
        }
        return internalObjects[position]
    }

    public func generate() -> Generator {
        return CoreDataBackedGenerator<T>(array: self)
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
            self.managedObjectContext.performBlockAndWait {
                guard let array = try? self.managedObjectContext.executeFetchRequest(fetchRequest) as? [NSManagedObject] else { return }
                self.managedArray = array ?? []
            }
        }
        let start = self.internalObjects.count
        let end = min(self.count, start + ((Int((position - start) / self.batchSize) + 1) * self.batchSize))

        let block: (Void) -> Void = {
            for i in start..<end {
                self.internalObjects.append(self.conversionFunction(self.managedArray[i]))
            }
        }

        if wait {
            self.managedObjectContext.performBlockAndWait(block)
        } else {
            self.managedObjectContext.performBlock(block)
        }
    }
}
