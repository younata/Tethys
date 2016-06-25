public protocol Analytics {
    func logEvent(event: String, data: [String: String]?)
}

import Mixpanel

func MixPanelToken() -> String {
    return NSBundle.mainBundle().objectForInfoDictionaryKey("MixpanelToken") as? String ?? ""
}

struct MixPanelAnalytics: Analytics {
    private let mixpanel = Mixpanel.sharedInstanceWithToken(MixPanelToken())

    func logEvent(event: String, data: [String : String]?) {
        if !_isDebugAssertConfiguration() {
            mixpanel.track(event, properties: data)
        }
    }
}
