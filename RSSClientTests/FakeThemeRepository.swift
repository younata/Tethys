import rNews
import Ra

class FakeThemeRepository: ThemeRepository {
    private var _backgroundColor = UIColor.whiteColor()
    override var backgroundColor: UIColor {
        get {
            return self._backgroundColor
        }
        set {
            self._backgroundColor = newValue
        }
    }

    private var _textColor = UIColor.blackColor()
    override var textColor: UIColor {
        get {
            return self._textColor
        }
        set {
            self._textColor = newValue
        }
    }

    private var _articleCSSFileName = "github2"
    override var articleCSSFileName: String {
        get {
            return self._articleCSSFileName
        }
        set {
            self._articleCSSFileName = newValue
        }
    }

    private var _syntaxFileName = "mac_classic"
    override var syntaxHighlightFile: String {
        get {
            return self._syntaxFileName
        }
        set {
            self._syntaxFileName = newValue
        }
    }

    private var _barStyle = UIBarStyle.Default
    override var barStyle: UIBarStyle {
        get {
            return self._barStyle
        }
        set {
            self._barStyle = newValue
        }
    }

    private var _tintColor = UIColor.whiteColor()
    override var tintColor: UIColor {
        get {
            return self._tintColor
        }
        set {
            self._tintColor = newValue
        }
    }

    init() {
        super.init(injector: Injector())
    }

    required init(injector: Injector) {
        fatalError("init(injector:) has not been implemented")
    }
}