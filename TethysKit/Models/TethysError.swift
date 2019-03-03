import Muon
import FutureHTTP

public enum NetworkError: Error, Equatable {
    case badResponse
    case cancelled
    case dns
    case http(HTTPError)
    case internetDown
    case serverNotFound
    case timedOut
    case unknown

    public var localizedDescription: String {
        switch self {
        case .badResponse:
            return NSLocalizedString("Error_Network_BadResponse", comment: "")
        case .cancelled:
            return NSLocalizedString("Error_Network_Cancelled", comment: "")
        case .dns:
            return NSLocalizedString("Error_Network_DNS", comment: "")
        case let .http(status):
            return status.description
        case .internetDown:
            return NSLocalizedString("Error_Network_InternetDown", comment: "")
        case .serverNotFound:
            return NSLocalizedString("Error_Network_ServerNotFound", comment: "")
        case .timedOut:
            return NSLocalizedString("Error_Network_TimedOut", comment: "")
        case .unknown:
            return NSLocalizedString("Error_Network_Unknown", comment: "")
        }
    }
}

extension NetworkError {
    init(httpClientError: HTTPClientError) {
        switch httpClientError {
        case .unknown, .url:
            self = .unknown
        case .security:
            self = .badResponse
        case .network(let networkError):
            switch networkError {
            case .cancelled:
                self = .cancelled
            case .timedOut:
                self = .timedOut
            case .cannotFindHost, .cannotConnectTohost:
                self = .serverNotFound
            case .connectionLost:
                self = .timedOut
            case .dnsFailed:
                self = .dns
            case .notConnectedToInternet:
                self = .internetDown
            }
        case .http:
            self = .badResponse
        }
    }
}

public enum DatabaseError: Error, Equatable {
    case notFound
    case entryNotFound
    case unknown

    public var localizedDescription: String {
        switch self {
        case .notFound:
            return NSLocalizedString("Error_Database_DatabaseNotFound", comment: "")
        case .entryNotFound:
            return NSLocalizedString("Error_Database_EntryNotFound", comment: "")
        case .unknown:
            return NSLocalizedString("Error_Database_Unknown", comment: "")
        }
    }
}

public enum TethysError: Error, Equatable {
    case network(URL, NetworkError)
    case http(Int)
    case database(DatabaseError)
    case feed(FeedParserError)
    case multiple([TethysError])
    case unknown

    public var localizedDescription: String {
        switch self {
        case let .network(url, error):
            return String.localizedStringWithFormat("Error_Standard_Network",
                                                    url.absoluteString,
                                                    error.localizedDescription)
        case let .http(status):
            return String.localizedStringWithFormat("Error_Standard_HTTP", status)
        case let .feed(error):
            return error.localizedDescription
        case let .multiple(errors):
            return errors.map { $0.localizedDescription }.joined(separator: ", ")
        case let .database(error):
            return error.localizedDescription
        case .unknown:
            return NSLocalizedString("Error_Standard_Unknown", comment: "")
        }
    }
}
