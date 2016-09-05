import CoreData

private let cacheName = "CoreDataFetchResultsController"

final class CoreDataFetchResultsController: FetchResultsController {
    typealias Element = NSManagedObject

    private let fetchResultsController: NSFetchedResultsController<AnyObject>
    private let initialError: RNewsError?

    var count: Int {
        return fetchResultsController.sections?.first?.numberOfObjects ?? 0
    }

    var predicate: NSPredicate {
        return self.fetchResultsController.fetchRequest.predicate ?? NSPredicate(value: true)
    }

    private var sortDescriptors: [NSSortDescriptor] {
        return self.fetchResultsController.fetchRequest.sortDescriptors ?? []
    }

    private var entityName: String {
        return self.fetchResultsController.fetchRequest.entityName ?? ""
    }

    init(entityName: String, managedObjectContext: NSManagedObjectContext,
         sortDescriptors: [NSSortDescriptor], predicate: NSPredicate) {
        let fetchRequest = NSFetchRequest(entityName: entityName)
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate

        self.fetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                 managedObjectContext: managedObjectContext,
                                                                 sectionNameKeyPath: nil,
                                                                 cacheName: cacheName)
        do {
            try self.fetchResultsController.performFetch()
            self.initialError = nil
        } catch {
            self.initialError = .database(DatabaseError.unknown)
        }
    }

    func get(_ index: Int) throws -> Element {
        if let error = self.initialError {
            throw error
        }
        if index < 0 || index >= self.count {
            throw RNewsError.database(.entryNotFound)
        }
        let indexPath = IndexPath(row: index, section: 0)
        return self.fetchResultsController.object(at: indexPath) as! Element
    }

    func insert(_ item: Element) throws {
        fatalError("Not implemented")
    }

    func delete(_ index: Int) throws {
        do {
            let object = try self.get(index)

            self.fetchResultsController.managedObjectContext.delete(object)

            NSFetchedResultsController.deleteCache(withName: cacheName)
            _ = try? self.fetchResultsController.performFetch()
        } catch RNewsError.database(let error) {
            throw error
        } catch {
            throw RNewsError.database(.unknown)
        }
    }

    func filter(_ predicate: NSPredicate) -> CoreDataFetchResultsController {
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [self.predicate, predicate])
        return self.replacePredicate(compoundPredicate)
    }

    func combine(_ fetchResultsController: CoreDataFetchResultsController) -> CoreDataFetchResultsController {
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [self.predicate,
            fetchResultsController.predicate])
        return self.replacePredicate(compoundPredicate)
    }

    func replacePredicate(_ predicate: NSPredicate) -> CoreDataFetchResultsController {
        let fetchRequest = self.fetchResultsController.fetchRequest
        return CoreDataFetchResultsController(entityName: fetchRequest.entityName ?? "",
                                              managedObjectContext: self.fetchResultsController.managedObjectContext,
                                              sortDescriptors: fetchRequest.sortDescriptors ?? [],
                                              predicate: predicate)
    }
}

func == (lhs: CoreDataFetchResultsController, rhs: CoreDataFetchResultsController) -> Bool {
    return lhs.entityName == rhs.entityName &&
        lhs.predicate == rhs.predicate &&
        lhs.sortDescriptors == rhs.sortDescriptors &&
        lhs.fetchResultsController.managedObjectContext == rhs.fetchResultsController.managedObjectContext
}
