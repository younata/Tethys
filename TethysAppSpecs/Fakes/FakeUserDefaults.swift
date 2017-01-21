import Foundation

class FakeUserDefaults: UserDefaults {

    private var internalDictionary: [String: Any] = [:]

    init() {
        super.init(suiteName: nil)!
    }

    override init?(suiteName suitename: String?) {
        super.init(suiteName: suitename)
    }

    override func object(forKey defaultName: String) -> Any? {
        return self.internalDictionary[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        self.internalDictionary.removeValue(forKey: defaultName)
    }

    override func string(forKey defaultName: String) -> String? {
        return self.internalDictionary[defaultName] as? String
    }

    override func array(forKey defaultName: String) -> [Any]? {
        return self.internalDictionary[defaultName] as? [Any]
    }

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        return self.internalDictionary[defaultName] as? [String: Any]
    }

    override func data(forKey defaultName: String) -> Data? {
        return self.internalDictionary[defaultName] as? Data
    }

    override func stringArray(forKey defaultName: String) -> [String]? {
        return self.internalDictionary[defaultName] as? [String]
    }

    override func integer(forKey defaultName: String) -> Int {
        return self.internalDictionary[defaultName] as? Int ?? 0
    }

    override func float(forKey defaultName: String) -> Float {
        return self.internalDictionary[defaultName] as? Float ?? 0.0
    }

    override func double(forKey defaultName: String) -> Double {
        return self.internalDictionary[defaultName] as? Double ?? 0.0
    }

    override func bool(forKey defaultName: String) -> Bool {
        return self.internalDictionary[defaultName] as? Bool ?? false
    }

    override func url(forKey defaultName: String) -> URL? {
        return self.internalDictionary[defaultName] as? URL
    }

    override func set(_ value: Int, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func set(_ value: Float, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func set(_ value: Double, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func set(_ url: URL?, forKey defaultName: String) {
        self.internalDictionary[defaultName] = url
    }

    override func synchronize() -> Bool {
        return true
    }
}
