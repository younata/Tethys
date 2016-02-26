import rNews
import Ra

class FakeThemeRepository: ThemeRepository {
    init() {
        super.init(userDefaults: nil)
    }

    required init(injector: Injector) {
        fatalError("init(injector:) has not been implemented")
    }
}