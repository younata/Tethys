func documentsDirectory() -> NSString {
    return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")
}

extension String {
    func stringByStrippingHTML() -> String {
        guard let removeEntityCodes = try? NSRegularExpression(pattern: "(&nbsp;|&#160;)", options: .CaseInsensitive),
            makeOneLine = try? NSRegularExpression(pattern: "[\n\r]", options: .CaseInsensitive),
            removeScripts = try? NSRegularExpression(pattern: "<script.*?</script>", options: .CaseInsensitive),
            removeHTMLTags = try? NSRegularExpression(pattern: "<.*?>", options: .CaseInsensitive) else {
                return self
        }

        let mutableString = NSMutableString(string: self)

        for regex in [removeEntityCodes, makeOneLine, removeScripts, removeHTMLTags] {
            regex.replaceMatchesInString(mutableString,
                options: [],
                range: NSMakeRange(0, mutableString.length),
                withTemplate: " ")
        }
        return mutableString.componentsSeparatedByString(" ").filter({!$0.isEmpty}).joinWithSeparator(" ")
    }

    func stringByUnescapingHTML() -> String {
        var result = self.stringByReplacingOccurrencesOfString("&quot;", withString: "\"")
        result = result.stringByReplacingOccurrencesOfString("&#39;", withString: "'")
        result = result.stringByReplacingOccurrencesOfString("&lt;", withString: "<")
        result = result.stringByReplacingOccurrencesOfString("&gt;", withString: ">")
        return result.stringByReplacingOccurrencesOfString("&amp;", withString: "&")
    }
}

func estimateReadingTime(htmlString: String) -> Int {
    let words = htmlString.stringByStrippingHTML().componentsSeparatedByString(" ")

    return Int(round(Double(words.count) / 200.0))
}
