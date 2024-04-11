import Foundation
import HTTPTypes

extension APIClient {

    /// When the rate limit is exceeded, the request will be repeated after the specified interval and all requests with the same identifier will be suspended.
    /// - Parameters:
    ///  - id: The identifier to use for rate limiting. Default to the base URL of the request.
    ///  - interval: The interval to wait before repeating the request. Default to 30 seconds.
    ///  - statusCodes: The set of status codes that indicate a rate limit exceeded. Default to `[429]`.
    ///  - maxRepeatCount: The maximum number of times the request can be repeated. Default to 3.
    public func waitIfRateLimitExceeded<ID: Hashable>(
        id: @escaping (HTTPRequestComponents) -> ID,
        interval: TimeInterval = 30,
        statusCodes: Set<HTTPResponse.Status> = [.tooManyRequests],
        maxRepeatCount: Int = 3
    ) -> Self {
        httpClientMiddleware(RateLimitMiddleware(id: id, interval: interval, statusCodes: statusCodes, maxCount: maxRepeatCount))
    }

    /// When the rate limit is exceeded, the request will be repeated after the specified interval and all requests with the same base URL will be suspended.
    /// - Parameters:
    ///  - interval: The interval to wait before repeating the request. Default to 30 seconds.
    ///  - statusCodes: The set of status codes that indicate a rate limit exceeded. Default to `[429]`.
    ///  - maxRepeatCount: The maximum number of times the request can be repeated. Default to 3.
    public func waitIfRateLimitExceeded(
        interval: TimeInterval = 30,
        statusCodes: Set<HTTPResponse.Status> = [.tooManyRequests],
        maxRepeatCount: Int = 3
    ) -> Self {
        waitIfRateLimitExceeded(
            id: { $0.url?.host ?? UUID().uuidString },
            interval: interval,
            statusCodes: statusCodes,
            maxRepeatCount: maxRepeatCount
        )
    }
}

private struct RateLimitMiddleware<ID: Hashable>: HTTPClientMiddleware {
    
    let id: (HTTPRequestComponents) -> ID
    let interval: TimeInterval
    let statusCodes: Set<HTTPResponse.Status>
    let maxCount: Int

    func execute<T>(
        request: HTTPRequestComponents,
        configs: APIClient.Configs,
        next: @escaping (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
    ) async throws -> (T, HTTPResponse) {
        let id = id(request)
        await waitForSynchronizedAccess(id: id, of: Void.self)
        var res = try await next(request, configs)
        var count: UInt = 0
        while
            statusCodes.contains(res.1.status),
            count < maxCount
        {
            count += 1
            try await withThrowingSynchronizedAccess(id: id) {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            res = try await next(request, configs)
        }
        return res
    }
}
