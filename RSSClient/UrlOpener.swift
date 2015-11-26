public protocol UrlOpener {
    func openURL(url: NSURL) -> Bool
}

extension UIApplication: UrlOpener {}
