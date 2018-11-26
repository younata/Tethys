public enum NetworkError: Error, Equatable {
    case internetDown
    case dns
    case serverNotFound
    case http(HTTPError)
    case unknown

    public var localizedDescription: String {
        switch self {
        case .internetDown:
            return NSLocalizedString("Error_Network_InternetDown", comment: "")
        case .dns:
            return NSLocalizedString("Error_Network_DNS", comment: "")
        case .serverNotFound:
            return NSLocalizedString("Error_Network_ServerNotFound", comment: "")
        case let .http(status):
            return status.description
        case .unknown:
            return NSLocalizedString("Error_Network_Unknown", comment: "")
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
    case multiple(Array<TethysError>)
    case unknown

    public var localizedDescription: String {
        switch self {
        case let .network(url, error):
            return String.localizedStringWithFormat("Error_Standard_Network",
                                                    url.absoluteString,
                                                    error.localizedDescription)
        case let .http(status):
            return String.localizedStringWithFormat("Error_Standard_HTTP", status)
        case let .multiple(errors):
            return errors.map { $0.localizedDescription }.joined(separator: ", ")
        case let .database(error):
            return error.localizedDescription
        case .unknown:
            return NSLocalizedString("Error_Standard_Unknown", comment: "")
        }
    }
}
