import Foundation

enum HTTPMethod {
    case delete
    case get
    case post(Data)
    case put(Data)

    var name: String {
        switch self {
        case .delete:
            return "DELETE"
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        }
    }

    var body: Data? {
        switch self {
        case .delete, .get:
            return nil
        case .post(let data), .put(let data):
            return data
        }
    }
}

extension URLRequest {
    init(url: URL, headers: [String: String], method: HTTPMethod = .get) {
        self.init(url: url)
        headers.forEach { key, value in self.addValue(value, forHTTPHeaderField: key)}
        self.httpMethod = method.name
        self.httpBody = method.body
    }
}

func formData(contents: [String: String]) -> Data {
    return contents.compactMap {
        guard let key = $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        guard let value = $1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "\(key)=\(value)"
    }.joined(separator: "&").data(using: .utf8)!
}
