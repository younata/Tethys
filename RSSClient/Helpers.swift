import Foundation

public func documentsDirectory() -> String {
    return NSHomeDirectory().stringByAppendingPathComponent("Documents")
}