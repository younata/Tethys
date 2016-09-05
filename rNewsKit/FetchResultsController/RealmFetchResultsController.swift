import Foundation
import RealmSwift
import Result

final class RealmFetchResultsController: FetchResultsController {
    typealias Element=Object

    let predicate: NSPredicate
    private let realmConfiguration: Realm.Configuration
    private let sortDescriptors: [SortDescriptor]
    private let model: Object.Type

    private var realmsForThreads: [Thread: Realm] = [:]
    private func realm() throws -> Realm {
        let thread = Thread.current
        if let realm = self.realmsForThreads[thread] {
            return realm
        }
        let realm = try Realm(configuration: realmConfiguration)
        self.realmsForThreads[thread] = realm
        return realm
    }

    private var realmObjects: Result<Results<Element>, RNewsError> {
        do {
            let realm = try self.realm()
            let objects = realm.objects(model).filter(predicate).sorted(sortDescriptors)
            return .Success(objects)
        } catch {
            return Result.Failure(.Database(.Unknown))
        }
    }


    init(configuration: Realm.Configuration, model: Object.Type,
         sortDescriptors: [SortDescriptor], predicate: NSPredicate) {
        self.realmConfiguration = configuration
        self.model = model
        self.sortDescriptors = sortDescriptors
        self.predicate = predicate
    }

    var count: Int {
        switch self.realmObjects {
        case let .Success(objects):
            return objects.count
        case .Failure(_):
            return 0
        }
    }

    func get(_ index: Int) throws -> Element {
        switch self.realmObjects {
        case let .Success(objects):
            if index < 0 || index >= self.count {
                throw RNewsError.database(.entryNotFound)
            }
            return objects[index]
        case let .Failure(error):
            throw error
        }
    }

    func insert(_ item: Element) throws {
        do {
            let realm = try self.realm()
            if realm.inWriteTransaction {
                realm.add(item)
            } else {
                try realm.write {
                    realm.add(item)
                }
            }
        } catch {
            throw RNewsError.database(.unknown)
        }
    }

    func delete(_ index: Int) throws {
        let object = try self.get(index)

        do {
            let realm = try self.realm()
            if realm.inWriteTransaction {
                realm.delete(object)
            } else {
                try realm.write {
                    realm.delete(object)
                }
            }
        } catch {
            throw RNewsError.database(.unknown)
        }
    }

    func replacePredicate(_ predicate: NSPredicate) -> RealmFetchResultsController {
        return RealmFetchResultsController(configuration: self.realmConfiguration,
                                           model: self.model,
                                           sortDescriptors: self.sortDescriptors,
                                           predicate: predicate)
    }
}

func == (lhs: RealmFetchResultsController, rhs: RealmFetchResultsController) -> Bool {
    return lhs.model == rhs.model &&
        lhs.sortDescriptors == rhs.sortDescriptors &&
        lhs.predicate == rhs.predicate
}
