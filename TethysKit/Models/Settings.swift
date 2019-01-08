import Foundation

public struct Settings: Hashable {
    public let maxNumberOfArticles: Int

    public init(maxNumberOfArticles: Int) {
        self.maxNumberOfArticles = maxNumberOfArticles
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.maxNumberOfArticles)
    }

    init(realmSettings: RealmSettings) {
        if realmSettings.maxNumberOfArticles >= 0 {
            self.maxNumberOfArticles = realmSettings.maxNumberOfArticles
        } else {
            self.maxNumberOfArticles = Int.max
        }
    }

    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        return lhs.maxNumberOfArticles == rhs.maxNumberOfArticles
    }
}
