import FutureHTTP

extension HTTPClientError {
    var tethys: TethysKit.NetworkError {
        switch self {
        case .unknown, .url:
            return .unknown
        case .network(let networkError):
            return networkError.tethys
        case .http, .security:
            return .badResponse
        }
    }
}

extension FutureHTTP.NetworkError {
    fileprivate var tethys: TethysKit.NetworkError {
        switch self {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timedOut
        case .cannotConnectTohost, .connectionLost:
            return .serverNotFound
        case .cannotFindHost, .dnsFailed:
            return .dns
        case .notConnectedToInternet:
            return .internetDown
        }
    }
}

extension HTTPResponse {
    var tethysError: TethysKit.NetworkError? {
        guard let status = self.status else { return .badResponse }

        guard let httpError = TethysKit.HTTPError(rawValue: status.rawValue) else {
            return nil
        }
        return .http(httpError, self.body)
    }
}
