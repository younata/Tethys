import Result
import CBGPromise
import FutureHTTP

private enum PageInfo: Equatable {
    case first
    case next(String)
    case last
}

public struct NetworkPagedIndex: Comparable, ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int
    let actualIndex: Int
    let isIndefiniteEnd: Bool

    public static func < (lhs: NetworkPagedIndex, rhs: NetworkPagedIndex) -> Bool {
        if lhs.isIndefiniteEnd { return false }

        return lhs.actualIndex < rhs.actualIndex
    }

    public init(actualIndex: Int, isIndefiniteEnd: Bool) {
        self.actualIndex = actualIndex
        self.isIndefiniteEnd = isIndefiniteEnd
    }

    public init(integerLiteral value: Self.IntegerLiteralType) {
        self.actualIndex = value
        self.isIndefiniteEnd = false
    }
}

public class NetworkPagedCollection<T>: Collection {
    public typealias Index = NetworkPagedIndex
    public typealias Element = T

    private let httpClient: HTTPClient
    private let requestFactory: (String?) -> URLRequest
    private let dataParser: (Data) throws -> ([T], String?)

    private var items: [T] = []
    private var batchCount: Int = 0

    private var finished: Bool { self.nextPageInfo != .last }

    init(httpClient: HTTPClient, requestFactory: @escaping (String?) -> URLRequest,
         dataParser: @escaping (Data) throws -> ([T], String?)) {
        self.httpClient = httpClient
        self.requestFactory = requestFactory
        self.dataParser = dataParser

        self.requestItems()
    }

    public var startIndex: Index { NetworkPagedIndex(actualIndex: self.items.startIndex, isIndefiniteEnd: false) }
    public var endIndex: Index { NetworkPagedIndex(actualIndex: self.items.endIndex, isIndefiniteEnd: self.finished) }

    public var underestimatedCount: Int { self.items.count }

    public subscript(index: Index) -> Element {
        let actualIndex = index.actualIndex
        // Determine whether to refetch because we're close the end of this page of data
        if self.shouldFetchNextResult(from: actualIndex) {
            self.requestItems(upTo: actualIndex)
        }
        guard actualIndex >= self.underestimatedCount else {
            return self.items[actualIndex]
        }
        while self.shouldWaitForNextRequest(index: actualIndex) {
            self.earliestRequest()?.wait()
        }

        if actualIndex >= self.underestimatedCount {
            fatalError("Error: Index out of range. " +
                "(Tried to get item at \(actualIndex), but only have items up to \(self.underestimatedCount)")
        }
        return self.items[actualIndex]
    }

    public func index(after: Index) -> Index {
        let nextIndex = self.items.index(after: after.actualIndex)
        if nextIndex == self.items.endIndex {
            return self.endIndex
        } else {
            return NetworkPagedIndex(actualIndex: nextIndex, isIndefiniteEnd: false)
        }
    }

    private var existingRequests: Set<URLRequest> = []
    private var inProgressRequests: OrderedDictionary<URLRequest, Future<Result<HTTPResponse, HTTPClientError>>> = [:]
    private var nextPageInfo: PageInfo = .first
    private func requestItems(upTo: Int? = nil) {
        let request: URLRequest
        switch nextPageInfo {
        case .last:
            return
        case .first:
            request = self.requestFactory(nil)
        case .next(let pageInfo):
            request = self.requestFactory(pageInfo)
        }

        guard !self.existingRequests.contains(request) else { return }

        let future = self.httpClient.request(request).then { result in
            self.inProgressRequests.removeValue(forKey: request)
            guard let response = result.value else {
                self.nextPageInfo = .last
                return
            }
            guard let (data, nextPage) = try? self.dataParser(response.body) else {
                self.nextPageInfo = .last
                return
            }
            self.batchCount = data.count
            self.items += data
            if let pageInfo = nextPage {
                self.nextPageInfo = .next(pageInfo)
            } else {
                self.nextPageInfo = .last
            }
            if let requestUpToIndex = upTo {
                guard self.underestimatedCount < requestUpToIndex && self.nextPageInfo != .last else { return }
                self.requestItems(upTo: upTo)
            }
        }
        self.existingRequests.insert(request)
        self.inProgressRequests[request] = future
    }

    private func earliestRequest() -> Future<Result<HTTPResponse, HTTPClientError>>? {
        return self.inProgressRequests.first?.value
    }

    private func shouldFetchNextResult(from index: Int) -> Bool {
        let zeroIndexedCount: Int = self.items.count - 1
        let distanceFromEnd: Double = Double(zeroIndexedCount - index)
        let percentageIndexIsAt: Double = distanceFromEnd / Double(self.batchCount)
        return percentageIndexIsAt <= 0.25
    }

    private func shouldWaitForNextRequest(index: Int) -> Bool {
        let mustMakeNextRequest = index > self.underestimatedCount
        let hasRequestInProgress = self.inProgressRequests.isEmpty == false
        return mustMakeNextRequest && hasRequestInProgress
    }
}
