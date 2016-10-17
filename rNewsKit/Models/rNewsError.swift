import Sinope

public enum NetworkError: Error {
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

extension NetworkError: Equatable {}

public func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
    switch (lhs, rhs) {
    case (.internetDown, .internetDown):
        return true
    case (.dns, .dns):
        return true
    case (.serverNotFound, .serverNotFound):
        return true
    case (let .http(lhsError), let .http(rhsError)):
        return lhsError == rhsError
    case (.unknown, .unknown):
        return true
    default:
        return false
    }
}

public enum DatabaseError: Error {
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
        return ""
    }
}

public enum RNewsError: Error {
    case network(URL, NetworkError)
    case http(Int)
    case database(DatabaseError)
    case backend(SinopeError)
    case unknown

    public var localizedDescription: String {
        switch self {
        case let .network(url, error):
            return String.localizedStringWithFormat("Error_Standard_Network",
                                                    url.absoluteString,
                                                    error.localizedDescription)
        case let .http(status):
            return String.localizedStringWithFormat("Error_Standard_HTTP", status)
        case let .database(error):
            return error.localizedDescription
        case let .backend(error):
            return error.localizedDescription
        case .unknown:
            return NSLocalizedString("Error_Standard_Unknown", comment: "")
        }
    }
}

extension RNewsError: Equatable {}

public func == (lhs: RNewsError, rhs: RNewsError) -> Bool {
    switch (lhs, rhs) {
    case (let .network(lhsurl, lhsError), let .network(rhsurl, rhsError)):
        return lhsurl == rhsurl && lhsError == rhsError
    case (let .http(lhsError), let .http(rhsError)):
        return lhsError == rhsError
    case (let .database(lhsError), let .database(rhsError)):
        return lhsError == rhsError
    case (let .backend(lhsError), let .backend(rhsError)):
        return lhsError == rhsError
    case (.unknown, .unknown):
        return true
    default:
        return false
    }
}
