import Result
import CBGPromise
import FutureHTTP

private enum PageInfo: Equatable {
    case first
    case next(String)
    case last
}

public class NetworkPagedCollection<T>: Collection {
    public typealias Index = Int
    public typealias Element = T

    private let httpClient: HTTPClient
    private let requestFactory: (String?) -> URLRequest
    private let dataParser: (Data) throws -> ([T], String?)

    private var items: [T] = []
    private var batchCount: Int = 0

    init(httpClient: HTTPClient, requestFactory: @escaping (String?) -> URLRequest,
         dataParser: @escaping (Data) throws -> ([T], String?)) {
        self.httpClient = httpClient
        self.requestFactory = requestFactory
        self.dataParser = dataParser

        self.requestItems()
    }

    public var startIndex: Int { return self.items.startIndex }
    public var endIndex: Int { return self.items.endIndex }

    public var underestimatedCount: Int { return self.items.count }

    public subscript(index: Index) -> Element {
        // Determine whether to refetch because we're close the end of this page of data
        if self.shouldFetchNextResult(from: index) {
            self.requestItems(upTo: index)
        }
        while self.shouldWaitForNextRequest(index: index) {
            self.earliestRequest()?.wait()
        }
        if index < self.underestimatedCount {
            return self.items[index]
        }

        fatalError("Error: Index out of range. " +
            "(Tried to get item at \(index), but only have items up to \(self.underestimatedCount)")
    }

    public func index(after: Index) -> Index {
        return items.index(after: after)
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
