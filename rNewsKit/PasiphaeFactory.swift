import Sinope

struct PasiphaeFactory {
    func baseURL() -> NSURL {
        let urlString = NSBundle.mainBundle().objectForInfoDictionaryKey("PasiphaeURL") as? String ?? ""
        return NSURL(string: urlString)!
    }

    func appToken() -> String {
        return NSBundle.mainBundle().objectForInfoDictionaryKey("PasiphaeToken") as? String ?? ""
    }

    func repository(networkClient: Sinope.NetworkClient) -> Sinope.Repository {
        return Sinope.DefaultRepository(
            self.baseURL(),
            networkClient: networkClient,
            appToken: self.appToken()
        )
    }
}