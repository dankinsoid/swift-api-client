import Foundation

/// A protocol that defines a type capable of configuring URLComponents.
public protocol URLComponentBuilder {

	/// The type of the result produced by the configure method.
	associatedtype BuildResult = Self

	/// Configures URLComponents by applying a closure to modify them.
	///
	/// - Parameter builder: A closure that modifies the URLComponents.
	/// - Throws: Rethrows any error thrown by the builder closure.
	/// - Returns: The modified URL or URLComponents as the result type.
	func configureURLComponents(_ builder: (inout URLComponents) throws -> Void) rethrows -> BuildResult
}

extension URLComponents: URLComponentBuilder {

	/// Configures URLComponents by applying a closure to modify them.
	///
	/// - Parameter builder: A closure that modifies the URLComponents.
	/// - Throws: Rethrows any error thrown by the builder closure.
	/// - Returns: The modified URLComponents instance.
	public func configureURLComponents(_ builder: (inout URLComponents) throws -> Void) rethrows -> URLComponents {
		var value = self
		try builder(&value)
		return value
	}
}

extension URL: URLComponentBuilder {

	/// Configures URL by applying a closure to modify URLComponents.
	///
	/// - Parameter builder: A closure that modifies the URLComponents.
	/// - Throws: Rethrows any error thrown by the builder closure.
	/// - Returns: The modified URL instance or the original URL if the modification fails.
	public func configureURLComponents(_ builder: (inout URLComponents) throws -> Void) rethrows -> URL {
		guard
			var value = URLComponents(url: self, resolvingAgainstBaseURL: false) ?? URLComponents(url: self, resolvingAgainstBaseURL: true)
		else { return self }
		try builder(&value)
		return value.url ?? self
	}
}

extension HTTPRequestComponents: URLComponentBuilder {

	/// Configures HTTPRequestComponents by applying a closure to modify URLComponents.
	///
	/// - Parameter builder: A closure that modifies the URLComponents.
	/// - Throws: Rethrows any error thrown by the builder closure.
	/// - Returns: The modified URLComponents instance.
	public func configureURLComponents(_ builder: (inout URLComponents) throws -> Void) rethrows -> HTTPRequestComponents {
		var value = self
		try builder(&value.urlComponents)
		return value
	}
}

// MARK: - Path modifiers

public extension URLComponentBuilder {

	/// Appends path components to the URL.
	/// - Parameters:
	///   - components: A variadic list of components that conform to `CustomStringConvertible`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with updated path.
	func path(_ components: any CustomStringConvertible..., percentEncoded: Bool = false) -> BuildResult {
		path(components, percentEncoded: percentEncoded)
	}

	/// Appends an array of path components to the URL.
	/// - Parameters:
	///   - components: An array of components that conform to `CustomStringConvertible`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with updated path.
	func path(_ components: [any CustomStringConvertible], percentEncoded: Bool = false) -> BuildResult {
		configureURLComponents {
			guard !components.isEmpty else { return }
			let items = components.flatMap {
				$0.description.components(separatedBy: ["/"]).filter { !$0.isEmpty }
			}
			for item in items {
				$0.appendPath(item, percentEncoded: percentEncoded)
			}
		}
	}
}

// MARK: - Query modifiers

public extension URLComponentBuilder {

	/// Adds URL query parameters using a closure providing an array of `URLQueryItem`.
	/// - Parameters:
	///   - items: A closure returning an array of `URLQueryItem` to be set as query parameters.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	func query(_ items: @escaping @autoclosure () throws -> [URLQueryItem], percentEncoded: Bool = false) rethrows -> BuildResult {
		try query(percentEncoded: percentEncoded) {
			try items()
		}
	}

	/// Adds URL query parameters with a closure that dynamically provides an array of `URLQueryItem` based on configurations.
	/// - Parameters:
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	///   - items: A closure building an array of `URLQueryItem`.
	/// - Returns: An instance with set query parameters.
	func query(percentEncoded: Bool = false, _ items: @escaping () throws -> [URLQueryItem]) rethrows -> BuildResult {
		try configureURLComponents { components in
			try components.addQueryItems(items: items(), percentEncoded: percentEncoded)
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the specified query parameter.
	func query(_ field: String, _ value: String?, percentEncoded: Bool = false) -> BuildResult {
		query(value.map { [URLQueryItem(name: field, value: $0)] } ?? [], percentEncoded: percentEncoded)
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `RawRepresentable`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the specified query parameter.
	func query<R: RawRepresentable>(_ field: String, _ value: R?, percentEncoded: Bool = false) -> BuildResult where R.RawValue == String {
		query(field, value?.rawValue, percentEncoded: percentEncoded)
	}

	/// Adds URL query parameters using an `Encodable` object.
	/// - Parameters:
	///   - items: An `Encodable` object to be used as query parameters.
	///   - queryEncoder: A `QueryEncoder` object.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	@_disfavoredOverload
	func query(_ items: any Encodable, queryEncoder: QueryEncoder = URLQueryEncoder(), percentEncoded: Bool = false) throws -> BuildResult {
		try query(percentEncoded: true) {
			try queryEncoder.encode(items, percentEncoded: !percentEncoded)
		}
	}

	/// Adds URL query parameters using a dictionary of JSON objects.
	/// - Parameters:
	///   - parameters: A dictionary of `String: Encodable?` pairs to be used as query parameters.
	///   - queryEncoder: A `QueryEncoder` object.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	func query(_ parameters: [String: Encodable?], queryEncoder: QueryEncoder = URLQueryEncoder(), percentEncoded: Bool = false) throws -> BuildResult {
		try query(percentEncoded: true) {
			try queryEncoder
				.encode(parameters.compactMapValues { $0.map { AnyEncodable($0) }}, percentEncoded: !percentEncoded)
				.sorted(by: { $0.name < $1.name })
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `Encodable`.
	///   - queryEncoder: A `QueryEncoder` object.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the specified query parameter.
	@_disfavoredOverload
	func query(_ field: String, _ value: Encodable?, queryEncoder: QueryEncoder = URLQueryEncoder(), percentEncoded: Bool = false) throws -> BuildResult {
		try query([field: value], queryEncoder: queryEncoder, percentEncoded: percentEncoded)
	}

	/// Adds URL query parameters using a dictionary of JSON objects.
	/// - Parameters:
	///   - parameters: A dictionary of `String: CustomStringConvertible?` pairs to be used as query parameters.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	func query(_ parameters: [String: CustomStringConvertible?], percentEncoded: Bool = false) -> BuildResult {
		query(percentEncoded: percentEncoded) {
			parameters.compactMapValues { $0?.queryDescription }
				.map { URLQueryItem(name: $0.key, value: $0.value) }
				.sorted(by: { $0.name < $1.name })
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `CustomStringConvertible`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the specified query parameter.
	@_disfavoredOverload
	func query(_ field: String, _ value: CustomStringConvertible?, percentEncoded: Bool = false) -> BuildResult {
		query([field: value], percentEncoded: percentEncoded)
	}
}

// MARK: - URL modifiers

public extension URLComponentBuilder {

	/// Sets the base URL.
	///
	/// - Parameters:
	///   - newBaseURL: The new base URL to set.
	/// - Returns: An instance with the updated base URL.
	///
	/// - Note: The query, and fragment of the original URL are retained, while those of the new URL are ignored.
	func baseURL(_ newBaseURL: URL) -> BuildResult {
		configureURLComponents {
			$0.scheme = newBaseURL.scheme
			#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
			if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
				if let host = newBaseURL.host(percentEncoded: false) {
					$0.host = host
				}
				let path = newBaseURL.path(percentEncoded: false)
				if !path.isEmpty, path != "/" {
					$0.prependPath(path)
				}
			} else {
				if let host = newBaseURL.host {
					$0.percentEncodedHost = host
				}
				if !newBaseURL.path.isEmpty, newBaseURL.path != "/" {
					$0.prependPath(newBaseURL.path, percentEncoded: true)
				}
			}
			#else
			if let host = newBaseURL.host {
				$0.percentEncodedHost = host
			}
			if !newBaseURL.path.isEmpty, newBaseURL.path != "/" {
				$0.prependPath(newBaseURL.path, percentEncoded: true)
			}
			#endif
			$0.port = newBaseURL.port
		}
	}

	/// Sets the scheme.
	///
	/// - Parameter scheme: The new scheme to set.
	/// - Returns: An instance with the updated scheme.
	func scheme(_ scheme: String) -> BuildResult {
		configureURLComponents {
			$0.scheme = scheme
		}
	}

	/// Sets the host.
	///
	/// - Parameters:
	///   - host: The new host to set.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the updated host.
	func host(_ host: String, percentEncoded: Bool = false) -> BuildResult {
		configureURLComponents {
			if percentEncoded {
				$0.percentEncodedHost = host
			} else {
				$0.host = host
			}
		}
	}

	/// Sets the port.
	///
	/// - Parameter port: The new port to set.
	/// - Returns: An instance with the updated port.
	func port(_ port: Int?) -> BuildResult {
		configureURLComponents {
			$0.port = port
		}
	}

	/// Sets the fragment for the url.
	///
	/// - Parameter fragment: The new fragment to set.
	/// - Returns: An instance with the updated port.
	func fragment(_ fragment: String?) -> BuildResult {
		configureURLComponents {
			$0.fragment = fragment
		}
	}
}

extension CustomStringConvertible {

	var queryDescription: String {
		if let collection = (self as? any Collection), !(self is any StringProtocol) {
			return collection.map { "\($0)" }.joined(separator: ",")
		}
		return description
	}
}
