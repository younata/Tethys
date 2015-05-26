import Foundation

func documentsDirectory() -> String {
    return NSHomeDirectory().stringByAppendingPathComponent("Documents")
}