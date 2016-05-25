public enum HTTPError: Int, CustomStringConvertible {
    case BadRequest = 400
    case Unauthorized = 401
    case PaymentRequired = 402
    case Forbidden = 403
    case NotFound = 404
    case MethodNotAllowed = 405
    case NotAcceptable = 406
    case ProxyRequired = 407
    case RequestTimeout = 408
    case Conflict = 409
    case Gone = 410
    case LengthRequired = 411
    case PreconditionFailed = 412
    case PayloadTooLarge = 413
    case URITooLong = 414
    case UnsupportedMediaType = 415
    case RangeNotSatisfiable = 416
    case ExpectationFailed = 417
    case ImATeapot = 418
    case MisdirectedRequest = 421
    case UnprocessableEntity = 422
    case Locked = 423
    case FailedDependency = 424
    case UpgradeRequired = 426
    case PreconditionRequired = 428
    case TooManyRequests = 429
    case RequestHeaderFieldsTooLarge = 431
    case UnavailableForLegalReasons = 451

    case InternalServerError = 500
    case NotImplemented = 501
    case BadGateway = 502
    case ServiceUnavailable = 503
    case GatewayTimeout = 504
    case HTTPVersionNotSupported = 505
    case VariantAlsoNegotiates = 506
    case InsufficientStorage = 507
    case LoopDetected = 508
    case NotExtended = 510
    case NetworkAuthenticationRequired = 511

    public var description: String {
        let suffix: String
        switch self {
        // 400 level
        case .BadRequest: suffix = "Bad Request"
        case .Unauthorized: suffix = "Unauthorized"
        case .PaymentRequired: suffix = "Payment Required"
        case .Forbidden: suffix = "Forbidden"
        case .NotFound: suffix = "Not Found"
        case .MethodNotAllowed: suffix = "Method Not Allowed"
        case .NotAcceptable: suffix = "Not Acceptable"
        case .ProxyRequired: suffix = "Proxy Required"
        case .RequestTimeout: suffix = "Request Timeout"
        case .Conflict: suffix = "Conflict"
        case .Gone: suffix = "Gone"
        case .LengthRequired: suffix = "Length Required"
        case .PreconditionFailed: suffix = "Precondition Failed"
        case .PayloadTooLarge: suffix = "Payload Too Large"
        case .URITooLong: suffix = "URI Too Long"
        case .UnsupportedMediaType: suffix = "Unsupported Media Type"
        case .RangeNotSatisfiable: suffix = "Range Not Satisfiable"
        case .ExpectationFailed: suffix = "Expectation Failed"
        case .ImATeapot: suffix = "I'm A Teapot"
        case .MisdirectedRequest: suffix = "Misdirected Request"
        case .UnprocessableEntity: suffix = "Unprocessable Entity"
        case .Locked: suffix = "Locked"
        case .FailedDependency: suffix = "Failed Dependency"
        case .UpgradeRequired: suffix = "Upgrade Required"
        case .PreconditionRequired: suffix = "Precondition Required"
        case .TooManyRequests: suffix = "Too Many Requests"
        case .RequestHeaderFieldsTooLarge: suffix = "Request Header Fields Too Large"
        case .UnavailableForLegalReasons: suffix = "Unavailable For Legal Reasons"

        // 500 level
        case .InternalServerError: suffix = "Internal Server Error"
        case .NotImplemented: suffix = "Not Implemented"
        case .BadGateway: suffix = "Bad Gateway"
        case .ServiceUnavailable: suffix = "Service Unavailable"
        case .GatewayTimeout: suffix = "Gateway Timeout"
        case .HTTPVersionNotSupported: suffix = "HTTP Version Not Supported"
        case .VariantAlsoNegotiates: suffix = "Variant Also Negotiates"
        case .InsufficientStorage: suffix = "Insufficient Storage"
        case .LoopDetected: suffix = "Loop Detected"
        case .NotExtended: suffix = "Not Extended"
        case .NetworkAuthenticationRequired: suffix = "Network Authentication Required"
        }
        return "\(self.rawValue) - \(suffix)"
    }
}
