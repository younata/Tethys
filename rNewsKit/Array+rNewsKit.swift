extension Array where Element: Equatable {
    public func objectPassingTest(predicate: (Element) throws -> Bool) rethrows -> Element? {
        let index = try self.index(where: predicate)
        if let index = index {
            return self[index]
        }
        return nil
    }
}
