import rNews

class FakeUrlOpener: UrlOpener {
    var url: NSURL? = nil
    func openURL(url: NSURL) -> Bool {
        self.url = url
        return true
    }

    init() {}
}