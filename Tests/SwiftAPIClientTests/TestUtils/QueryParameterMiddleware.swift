import Foundation
@testable import SwiftAPIClient

/// Test middleware that adds missing query parameters to requests.
struct QueryParameterMiddleware: HTTPClientMiddleware {
    
    private let defaultParameters: [String: String]
    
    /// Initialize with default parameters to add when missing.
    /// - Parameter defaultParameters: Dictionary of parameter names and values to add when missing from the request.
    init(defaultParameters: [String: String]) {
        self.defaultParameters = defaultParameters
    }
    
    func execute<T>(
        request: HTTPRequestComponents,
        configs: APIClient.Configs,
        next: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
    ) async throws -> (T, HTTPResponse) {
        var modifiedRequest = request
        
        // Get existing query items
        let existingQueryItems = modifiedRequest.urlComponents.queryItems ?? []
        let existingParameterNames = Set(existingQueryItems.map(\.name))
        
        // Add missing parameters
        var newQueryItems = existingQueryItems
        for (name, value) in defaultParameters {
            if !existingParameterNames.contains(name) {
                newQueryItems.append(URLQueryItem(name: name, value: value))
            }
        }
        
        modifiedRequest.urlComponents.queryItems = newQueryItems.isEmpty ? nil : newQueryItems
        
        return try await next(modifiedRequest, configs)
    }
}
