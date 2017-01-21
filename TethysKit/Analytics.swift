public protocol Analytics {
    func logEvent(_ event: String, data: [String: String]?)
}

#if os(iOS)
import Mixpanel

func MixPanelToken() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "MixpanelToken") as? String ?? ""
}

struct MixPanelAnalytics: Analytics {
    private let mixpanel = Mixpanel.sharedInstance(withToken: MixPanelToken())

    func logEvent(_ event: String, data: [String : String]?) {
        if !_isDebugAssertConfiguration() {
            mixpanel.track(event, properties: data)
        }
    }
}
#endif
