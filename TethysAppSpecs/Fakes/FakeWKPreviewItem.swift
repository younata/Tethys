import WebKit

class FakeWKPreviewItem: WKPreviewElementInfo {
    private var _link: URL?

    override var linkURL: URL? { return self._link }

    init(link: URL?) {
        self._link = link

        super.init()
    }
}
