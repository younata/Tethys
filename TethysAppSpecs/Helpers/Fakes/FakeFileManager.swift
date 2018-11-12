import Foundation

class FakeFileManager: FileManager {

    var contentsOfDirectories: [String: [String]] = [:]

    override func contentsOfDirectory(atPath path: String) throws -> [String] {
        guard let contents = self.contentsOfDirectories[path] else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }

        return contents
    }
}
