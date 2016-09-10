import Sinope

public enum NetworkError: Error, CustomStringConvertible {
    case internetDown
    case dns
    case serverNotFound
    case http(HTTPError)
    case unknown

    public var description: String {
        switch self {
        case .internetDown: return "Internet Down"
        case .dns: return "DNS Error"
        case .serverNotFound: return "Server Not Found"
        case let .http(status): return status.description
        case .unknown: return "Unknown Error"
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

public enum DatabaseError: Error, CustomStringConvertible {
    case notFound
    case unknown
    case entryNotFound

    public var description: String {
        return ""
    }
}

public enum RNewsError: Error, CustomStringConvertible {
    case network(URL, NetworkError)
    case http(Int)
    case database(DatabaseError)
    case backend(SinopeError)
    case unknown

    public var description: String {
        switch self {
        case let .network(url, error):
            return "Unable to load \(url) - \(error)"
        case let .http(status):
            return "Error loading resource, received \(status)"
        case let .database(error):
            return "Error reading from database - \(error)"
        case let .backend(error):
            return "Backend Error - \(error)"
        case .unknown:
            return "Unknown Error - please try again"
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
