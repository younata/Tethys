import Foundation

enum HTTPMethod {
    case get
    case put(Data)
    case post(Data)
    case delete

    var name: String {
        switch self {
        case .get:
            return "GET"
        case .put:
            return "PUT"
        case .post:
            return "POST"
        case .delete:
            return "DELETE"
        }
    }

    var body: Data? {
        switch self {
        case .get, .delete:
            return nil
        case .put(let data):
            return data
        case .post(let data):
            return data
        }
    }
}

func request(url: String, headers: [String: String], method: HTTPMethod = .get) -> URLRequest {
    var request = URLRequest(url: URL(string: url)!)
    headers.forEach { key, value in
        request.addValue(value, forHTTPHeaderField: key)
    }
    request.httpMethod = method.name
    request.httpBody = method.body

    return request
}
