import CBGPromise
import Result

func documentsDirectory() -> String {
    return NSHomeDirectory() + "/Documents"
}

extension String {
    func stringByStrippingHTML() -> String {
        guard let removeEntityCodes = try? NSRegularExpression(pattern: "(&nbsp;|&#160;)", options: .caseInsensitive),
            let makeOneLine = try? NSRegularExpression(pattern: "[\n\r]", options: .caseInsensitive),
            let removeScripts = try? NSRegularExpression(pattern: "<script.*?</script>", options: .caseInsensitive),
            let removeHTMLTags = try? NSRegularExpression(pattern: "<.*?>", options: .caseInsensitive) else {
                return self
        }

        let mutableString = NSMutableString(string: self)

        for regex in [removeEntityCodes, makeOneLine, removeScripts, removeHTMLTags] {
            regex.replaceMatches(in: mutableString,
                options: [],
                range: NSRange(location: 0, length: mutableString.length),
                withTemplate: " ")
        }
        return mutableString.components(separatedBy: " ").filter({!$0.isEmpty}).joined(separator: " ")
    }

    func stringByUnescapingHTML() -> String {
        var result = self.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    var optional: String? {
        return self.isEmpty ? nil : self
    }
}

func estimateReadingTime(_ htmlString: String) -> TimeInterval {
    let words = htmlString.stringByStrippingHTML().components(separatedBy: " ")

    let readingTime = TimeInterval(words.count) / 200.0 * 60.0
    return readingTime
}

extension Promise {
    static func resolved<T>(_ value: T) -> Future<T> {
        let promise = Promise<T>()
        promise.resolve(value)
        return promise.future
    }
}

extension Result where Result.Error: Swift.Error {
    func mapFuture<U>(_ transform: (Value) -> Future<Result<U, Error>>) -> Future<Result<U, Error>> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return Promise<Result<U, Error>>.resolved(Result<U, Error>.failure(error))
        }
    }
}
