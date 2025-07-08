import Foundation

public protocol APIClientScope {

	/// The API client used in this scope.
	var client: APIClient { get set }
}

extension APIClientScope {

	/// Returns a copy of the API client scope with the client transformed by the given closure.
	public func mapClient(_ transform: (APIClient) -> APIClient) -> Self {
		var copy = self
		copy.client = transform(copy.client)
		return copy
	}
}
