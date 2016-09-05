public enum HTTPError: Int, CustomStringConvertible {
    case badRequest = 400
    case unauthorized = 401
    case paymentRequired = 402
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case notAcceptable = 406
    case proxyRequired = 407
    case requestTimeout = 408
    case conflict = 409
    case gone = 410
    case lengthRequired = 411
    case preconditionFailed = 412
    case payloadTooLarge = 413
    case uriTooLong = 414
    case unsupportedMediaType = 415
    case rangeNotSatisfiable = 416
    case expectationFailed = 417
    case imATeapot = 418
    case misdirectedRequest = 421
    case unprocessableEntity = 422
    case locked = 423
    case failedDependency = 424
    case upgradeRequired = 426
    case preconditionRequired = 428
    case tooManyRequests = 429
    case requestHeaderFieldsTooLarge = 431
    case unavailableForLegalReasons = 451

    case internalServerError = 500
    case notImplemented = 501
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeout = 504
    case httpVersionNotSupported = 505
    case variantAlsoNegotiates = 506
    case insufficientStorage = 507
    case loopDetected = 508
    case notExtended = 510
    case networkAuthenticationRequired = 511

    public var description: String {
        let suffix: String
        switch self {
        // 400 level
        case .badRequest: suffix = "Bad Request"
        case .unauthorized: suffix = "Unauthorized"
        case .paymentRequired: suffix = "Payment Required"
        case .forbidden: suffix = "Forbidden"
        case .notFound: suffix = "Not Found"
        case .methodNotAllowed: suffix = "Method Not Allowed"
        case .notAcceptable: suffix = "Not Acceptable"
        case .proxyRequired: suffix = "Proxy Required"
        case .requestTimeout: suffix = "Request Timeout"
        case .conflict: suffix = "Conflict"
        case .gone: suffix = "Gone"
        case .lengthRequired: suffix = "Length Required"
        case .preconditionFailed: suffix = "Precondition Failed"
        case .payloadTooLarge: suffix = "Payload Too Large"
        case .uriTooLong: suffix = "URI Too Long"
        case .unsupportedMediaType: suffix = "Unsupported Media Type"
        case .rangeNotSatisfiable: suffix = "Range Not Satisfiable"
        case .expectationFailed: suffix = "Expectation Failed"
        case .imATeapot: suffix = "I'm A Teapot"
        case .misdirectedRequest: suffix = "Misdirected Request"
        case .unprocessableEntity: suffix = "Unprocessable Entity"
        case .locked: suffix = "Locked"
        case .failedDependency: suffix = "Failed Dependency"
        case .upgradeRequired: suffix = "Upgrade Required"
        case .preconditionRequired: suffix = "Precondition Required"
        case .tooManyRequests: suffix = "Too Many Requests"
        case .requestHeaderFieldsTooLarge: suffix = "Request Header Fields Too Large"
        case .unavailableForLegalReasons: suffix = "Unavailable For Legal Reasons"

        // 500 level
        case .internalServerError: suffix = "Internal Server Error"
        case .notImplemented: suffix = "Not Implemented"
        case .badGateway: suffix = "Bad Gateway"
        case .serviceUnavailable: suffix = "Service Unavailable"
        case .gatewayTimeout: suffix = "Gateway Timeout"
        case .httpVersionNotSupported: suffix = "HTTP Version Not Supported"
        case .variantAlsoNegotiates: suffix = "Variant Also Negotiates"
        case .insufficientStorage: suffix = "Insufficient Storage"
        case .loopDetected: suffix = "Loop Detected"
        case .notExtended: suffix = "Not Extended"
        case .networkAuthenticationRequired: suffix = "Network Authentication Required"
        }
        return "\(self.rawValue) - \(suffix)"
    }
}
