public enum NetworkError: ErrorType, CustomStringConvertible {
    case InternetDown
    case DNS
    case ServerNotFound
    case HTTP(HTTPError)
    case Unknown

    public var description: String {
        switch self {
        case .InternetDown: return "Internet Down"
        case .DNS: return "DNS Error"
        case .ServerNotFound: return "Server Not Found"
        case let .HTTP(status): return status.description
        case .Unknown: return "Unknown Error"
        }
    }
}

extension NetworkError: Equatable {}

public func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
    switch (lhs, rhs) {
    case (.InternetDown, .InternetDown):
        return true
    case (.DNS, .DNS):
        return true
    case (.ServerNotFound, .ServerNotFound):
        return true
    case (let .HTTP(lhsError), let .HTTP(rhsError)):
        return lhsError == rhsError
    case (.Unknown, .Unknown):
        return true
    default:
        return false
    }
}

public enum DatabaseError: ErrorType {
    case NotFound
    case Unknown
    case EntryNotFound
}

public enum RNewsError: ErrorType {
    case Network(NSURL, NetworkError)
    case HTTP(Int)
    case Database(DatabaseError)
    case Unknown
}

extension RNewsError: Equatable {}

public func == (lhs: RNewsError, rhs: RNewsError) -> Bool {
    switch (lhs, rhs) {
    case (let .Network(lhsurl, lhsError), let .Network(rhsurl, rhsError)):
        return lhsurl == rhsurl && lhsError == rhsError
    case (let .HTTP(lhsError), let .HTTP(rhsError)):
        return lhsError == rhsError
    case (let .Database(lhsError), let .Database(rhsError)):
        return lhsError == rhsError
    case (.Unknown, .Unknown):
        return true
    default:
        return false
    }
}
