import Foundation

class FakeFileManager: NSFileManager {

    var contentsOfDirectories: [String: [String]] = [:]

    override func contentsOfDirectoryAtPath(path: String) throws -> [String] {
        guard let contents = self.contentsOfDirectories[path] else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }

        return contents
    }
}