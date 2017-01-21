import Sinope

struct PasiphaeFactory {
    func baseURL() -> URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "PasiphaeURL") as? String ?? "https://example.com"
        // Don't crash in test.
        return URL(string: urlString)!
    }

    func appToken() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "PasiphaeToken") as? String ?? ""
    }

    func repository(_ networkClient: Sinope.NetworkClient) -> Sinope.Repository {
        return Sinope.DefaultRepository(
            self.baseURL(),
            networkClient: networkClient,
            appToken: self.appToken()
        )
    }
}
