@testable import rNewsKit

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

class FakeDataServiceFactory : DataServiceFactoryType {
    init() {
        self.set_currentDataServiceArgs = []
    }
    private var _currentDataService : DataService?
    private var set_currentDataServiceArgs : Array<DataService>

    var currentDataService : DataService {
        get {
            return _currentDataService!
        }

        set {
            _currentDataService = newValue
            set_currentDataServiceArgs.append(newValue)
        }
    }

    func setCurrentDataServiceCallCount() -> Int {
        return set_currentDataServiceArgs.count
    }

    func setCurrentDataServiceArgsForCall(_ index : Int) throws -> DataService {
        if index < 0 || index >= set_currentDataServiceArgs.count {
            throw NSError.init(domain: "swift-generate-fake-domain", code: 1, userInfo: nil)
        }
        return set_currentDataServiceArgs[index]
    }

    private(set) var newDataServiceCallCount : Int = 0
    var newDataServiceStub : (() -> (DataService))?
    func newDataServiceReturns(_ stubbedValues: (DataService)) {
        self.newDataServiceStub = {() -> (DataService) in
            return stubbedValues
        }
    }
    func newDataService() -> (DataService) {
        self.newDataServiceCallCount += 1
        return self.newDataServiceStub!()
    }

    static func reset() {
    }
}
