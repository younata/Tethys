import Foundation

class FakeUserDefaults: NSUserDefaults {

    private var internalDictionary: [String: AnyObject] = [:]

    init() {
        super.init(suiteName: nil)!
    }

    override init?(suiteName suitename: String?) {
        super.init(suiteName: suitename)
    }

    override func objectForKey(defaultName: String) -> AnyObject? {
        return self.internalDictionary[defaultName]
    }

    override func setObject(value: AnyObject?, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func removeObjectForKey(defaultName: String) {
        self.internalDictionary.removeValueForKey(defaultName)
    }

    override func stringForKey(defaultName: String) -> String? {
        return self.internalDictionary[defaultName] as? String
    }

    override func arrayForKey(defaultName: String) -> [AnyObject]? {
        return self.internalDictionary[defaultName] as? [AnyObject]
    }

    override func dictionaryForKey(defaultName: String) -> [String : AnyObject]? {
        return self.internalDictionary[defaultName] as? [String: AnyObject]
    }

    override func dataForKey(defaultName: String) -> NSData? {
        return self.internalDictionary[defaultName] as? NSData
    }

    override func stringArrayForKey(defaultName: String) -> [String]? {
        return self.internalDictionary[defaultName] as? [String]
    }

    override func integerForKey(defaultName: String) -> Int {
        return self.internalDictionary[defaultName] as? Int ?? 0
    }

    override func floatForKey(defaultName: String) -> Float {
        return self.internalDictionary[defaultName] as? Float ?? 0.0
    }

    override func doubleForKey(defaultName: String) -> Double {
        return self.internalDictionary[defaultName] as? Double ?? 0.0
    }

    override func boolForKey(defaultName: String) -> Bool {
        return self.internalDictionary[defaultName] as? Bool ?? false
    }

    override func URLForKey(defaultName: String) -> NSURL? {
        return self.internalDictionary[defaultName] as? NSURL
    }

    override func setInteger(value: Int, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func setFloat(value: Float, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func setDouble(value: Double, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func setBool(value: Bool, forKey defaultName: String) {
        self.internalDictionary[defaultName] = value
    }

    override func setURL(url: NSURL?, forKey defaultName: String) {
        self.internalDictionary[defaultName] = url
    }

    override func synchronize() -> Bool {
        return true
    }
}