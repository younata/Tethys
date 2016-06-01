import Foundation
import RealmSwift
import Result

struct RealmFetchResultsController<T: Object>: FetchResultsController {
    typealias Element=T

    private let realmConfiguration: Realm.Configuration
    private let sortDescriptors: [SortDescriptor]
    private let predicate: NSPredicate
    private let realmObjects: Result<Results<Element>, RNewsError>

    private func realm() throws -> Realm {
        return try Realm(configuration: realmConfiguration)
    }


    init(configuration: Realm.Configuration, sortDescriptors: [SortDescriptor], predicate: NSPredicate) {
        self.realmConfiguration = configuration
        self.sortDescriptors = sortDescriptors
        self.predicate = predicate

        do {
            let realm = try Realm(configuration: configuration)
            let objects = realm.objects(T).filter(predicate).sorted(sortDescriptors)
            self.realmObjects = .Success(objects)
        } catch {
            self.realmObjects = Result.Failure(.Database(.Unknown))
        }
    }

    var count: Int {
        switch self.realmObjects {
        case let .Success(objects):
            return objects.count
        case .Failure(_):
            return 0
        }
    }

    subscript(index: Int) -> Element {
        // swiftlint:disable force_try
        return try! self.get(index)
        // swiftlint:enable force_try
    }

    func get(index: Int) throws -> Element {
        switch self.realmObjects {
        case let .Success(objects):
            if index < 0 || index >= self.count {
                throw RNewsError.Database(.EntryNotFound)
            }
            return objects[index]
        case let .Failure(error):
            throw error
        }
    }

    mutating func insert(item: Element) throws {
        do {
            let realm = try Realm(configuration: self.realmConfiguration)
            try realm.write {
                realm.add(item)
            }
        } catch {
            throw RNewsError.Database(.Unknown)
        }
    }

    mutating func delete(index: Int) throws {
        let object = try self.get(index)

        do {
            let realm = try Realm(configuration: self.realmConfiguration)
            try realm.write {
                realm.delete(object)
            }
        } catch {
            throw RNewsError.Database(.Unknown)
        }
    }
}
