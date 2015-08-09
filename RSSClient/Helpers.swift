import Foundation

public func documentsDirectory() -> NSString {
    return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")
}