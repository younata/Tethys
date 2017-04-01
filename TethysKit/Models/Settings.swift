import Foundation

public struct Settings {
    public let maxNumberOfArticles: Int?

    public init(maxNumberOfArticles: Int?) {
        self.maxNumberOfArticles = maxNumberOfArticles
    }

    init(realmSettings: RealmSettings) {
        if realmSettings.maxNumberOfArticles >= 0 {
            self.maxNumberOfArticles = realmSettings.maxNumberOfArticles
        } else {
            self.maxNumberOfArticles = nil
        }
    }
}
