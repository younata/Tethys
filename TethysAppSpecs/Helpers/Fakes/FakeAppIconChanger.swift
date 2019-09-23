import Tethys

final class FakeAppIconChanger: AppIconChanger {

    var supportsAlternateIcons: Bool = false

    var alternateIconName: String? = nil

    var setAlternateIconCalls: [(name: String?, handler: ((Error?) -> Void)?)] = []
    func setAlternateIconName(_ alternateIconName: String?, completionHandler: ((Error?) -> Void)?) {
        self.setAlternateIconCalls.append((alternateIconName, completionHandler))
    }
}
