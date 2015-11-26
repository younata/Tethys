internal func documentsDirectory() -> NSString {
    return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")
}
