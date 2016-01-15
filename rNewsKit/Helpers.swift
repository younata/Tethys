func documentsDirectory() -> NSString {
    return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")
}

func estimateReadingTime(htmlString: String) -> Int {
    guard let removeEntityCodes = try? NSRegularExpression(pattern: "(&nbsp;|&#160;)", options: .CaseInsensitive),
        makeOneLine = try? NSRegularExpression(pattern: "[\n\r]", options: .CaseInsensitive),
        removeScripts = try? NSRegularExpression(pattern: "<script.*?</script>", options: .CaseInsensitive),
        removeHTMLTags = try? NSRegularExpression(pattern: "<.*?>", options: .CaseInsensitive) else {
            return 0
    }

    let mutableString = NSMutableString(string: htmlString)

    for regex in [removeEntityCodes, makeOneLine, removeScripts, removeHTMLTags] {
        regex.replaceMatchesInString(mutableString,
            options: [],
            range: NSMakeRange(0, mutableString.length),
            withTemplate: " ")
    }

    let words = mutableString.componentsSeparatedByString(" ")

    return Int(round(Double(words.count) / 200.0))
}
