import Quick
import Nimble
import CoreData
import RealmSwift
@testable import rNewsKit

class DataServiceFactorySpec: QuickSpec {
    override func spec() {
        let bundle = NSBundle(forClass: KitModule.classForCoder())
        let fileManager = NSFileManager.defaultManager()
        describe("currentDataService") {
            it("returns a CoreDataService if we haven't migrated yet") {
                _ = try? fileManager.removeItemAtPath(Realm.Configuration.defaultConfiguration.path!)

                let mainQueue = FakeOperationQueue()
                let searchIndex = FakeSearchIndex()
                let subject = DataServiceFactory(mainQueue: mainQueue, searchIndex: searchIndex, bundle: bundle, fileManager: fileManager)

                expect(subject.currentDataService is CoreDataService) == true
            }

            it("returns a new realm service if we have migrated") {
                let mainQueue = FakeOperationQueue()
                let searchIndex = FakeSearchIndex()

                try! Realm().write({})

                let subject = DataServiceFactory(mainQueue: mainQueue, searchIndex: searchIndex, bundle: bundle, fileManager: fileManager)
                let dataService = subject.currentDataService
                expect(dataService is RealmService) == true

                expect(dataService.searchIndex as? FakeSearchIndex) === searchIndex
                expect(dataService.mainQueue) === mainQueue

                expect(subject.currentDataService as? RealmService) === (dataService as! RealmService)
            }

            it("caches existing data services") {
                let mainQueue = FakeOperationQueue()
                let searchIndex = FakeSearchIndex()
                let subject = DataServiceFactory(mainQueue: mainQueue, searchIndex: searchIndex, bundle: bundle, fileManager: fileManager)
                let inMemoryDataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: searchIndex)
                subject.currentDataService = inMemoryDataService
                expect(subject.currentDataService as? InMemoryDataService) === inMemoryDataService
            }
        }

        describe("newDataService") {
            it("returns a RealmDataService") {
                let mainQueue = FakeOperationQueue()
                let searchIndex = FakeSearchIndex()
                let subject = DataServiceFactory(mainQueue: mainQueue, searchIndex: searchIndex, bundle: bundle, fileManager: fileManager)
                let dataService = subject.newDataService()
                expect(dataService is RealmService) == true

                expect(dataService.searchIndex as? FakeSearchIndex) === searchIndex
                expect(dataService.mainQueue) === mainQueue
            }
        }
    }
}
