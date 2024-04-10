@preconcurrency import Foundation
import HTTPTypes

public protocol RequestBuilder<Request, Configs> {

    associatedtype Request = HTTPRequestComponents
    associatedtype Configs = APIClient.Configs

    func modifyRequest(
        _ modifier: @escaping (inout Request, Configs) throws -> Void
    ) -> Self
    func request() throws -> Request
}

extension RequestBuilder {

    /// Modifies the URL request using the provided closure.
    ///   - location: When the request should be modified.
    ///   - modifier: A closure that takes `inout HTTPRequestComponents` and modifies the URL request.
    /// - Returns: An instance of `APIClient` with a modified URL request.
    public func modifyRequest(
        _ modifier: @escaping (inout Request) throws -> Void
    ) -> Self {
        modifyRequest { req, _ in
            try modifier(&req)
        }
    }
}
