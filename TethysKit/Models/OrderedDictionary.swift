struct OrderedDictionary<Key: Hashable, Value>: Collection, ExpressibleByDictionaryLiteral {
    typealias Element = (key: Key, value: Value)

    typealias Index = Array<Value>.Index

    var values: [Value] = []
    var keys: [Key] { return Array(self.contents.keys) }
    private var contents: [Key: Int] = [:]

    var startIndex: OrderedDictionary<Key, Value>.Index { return values.startIndex }
    var endIndex: OrderedDictionary<Key, Value>.Index { return values.endIndex }

    init(dictionaryLiteral elements: (Key, Value)...) {
        for element in elements {
            self[element.0] = element.1
        }
    }

    subscript(position: Array<Value>.Index) -> (key: Key, value: Value) {
        let key = self.contents.first { _, index in index == position }!
        return (key.key, self.values[position])
    }

    func index(after i: Array<Value>.Index) -> Array<Value>.Index {
        return self.values.index(after: i)
    }

    subscript(_ key: Key) -> Value? {
        get {
            guard let index = contents[key] else { return nil }
            return values[index]
        }
        set {
            if let value = newValue {
                if let index = contents[key] {
                    values.remove(at: index)
                    values.insert(value, at: index)
                } else {
                    let index = contents[key] ?? values.endIndex
                    values.append(value)
                    contents[key] = index
                }
            } else {
                _ = self.removeValue(forKey: key)
                guard let index = contents[key] else { return }
                contents[key] = nil
                values.remove(at: index)
            }
        }
    }

    @discardableResult mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = contents[key] else { return nil }
        contents[key] = nil

        return values.remove(at: index)
    }
}
