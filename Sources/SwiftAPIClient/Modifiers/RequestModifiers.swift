import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Path modifiers

public extension RequestBuilder where Request == HTTPRequestComponents {

	/// Appends path components to the URL of the request.
	/// - Parameters:
	///   - path: A first item of path.
	///   - suffix: A variadic list of components that conform to `CustomStringConvertible`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with updated path.
	func callAsFunction(_ path: CustomStringConvertible, _ suffix: any CustomStringConvertible..., percentEncoded: Bool = false) -> Self {
		self.path([path] + suffix, percentEncoded: percentEncoded)
	}

	/// Appends path components to the URL of the request.
	/// - Parameters:
	///   - components: A variadic list of components that conform to `CustomStringConvertible`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with updated path.
	@_disfavoredOverload
	func path(_ components: any CustomStringConvertible..., percentEncoded: Bool = false) -> Self {
		path(components.map(\.description), percentEncoded: percentEncoded)
	}

	/// Appends an array of path components to the URL of the request.
	/// - Parameters:
	///   - components: An array of components.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with updated path.
	func path(_ components: [String], percentEncoded: Bool = false) -> Self {
		modifyRequest {
			$0 = $0.path(components, percentEncoded: percentEncoded)
		}
	}
}

// MARK: - Method modifiers

public extension RequestBuilder where Request == HTTPRequestComponents {

	/// Sets the HTTP method for the request.
	/// - Parameter method: The `HTTPRequest.Method` to set for the request.
	/// - Returns: An instance with the specified HTTP method.
	func method(_ method: HTTPRequest.Method) -> Self {
		modifyRequest {
			$0.method = method
		}
	}

	/// Sets the HTTP `GET` method for the request.
	var get: Self { method(.get) }
	/// Sets the HTTP `POST` method for the request.
	var post: Self { method(.post) }
	/// Sets the HTTP `PUT` method for the request.
	var put: Self { method(.put) }
	/// Sets the HTTP `DELETE` method for the request.
	var delete: Self { method(.delete) }
	/// Sets the HTTP `PATCH` method for the request.
	var patch: Self { method(.patch) }
}

// MARK: - Headers modifiers

public extension RequestBuilder where Request == HTTPRequestComponents {

	/// Adds or updates HTTP headers for the request.
	/// - Parameters:
	///   - headers: A closure providing an array of `HTTPField` to add or update.
	///   - removeCurrent: A Boolean to determine whether to remove existing headers with these keys. Default is `false`.
	/// - Returns: An instance with modified headers.
	func headers(removeCurrent: Bool = false, _ headers: @escaping (Configs) throws -> [HTTPField]) -> Self {
		modifyRequest { request, configs in
			for header in try headers(configs) {
				if removeCurrent {
					request.headers[fields: header.name] = [header]
				} else {
					var field = request.headers[fields: header.name]
					field.append(header)
					request.headers[fields: header.name] = field
				}
			}
		}
	}

	/// Adds or updates HTTP headers for the request.
	/// - Parameters:
	///   - headers: A variadic list of `HTTPField` to set or update.
	///   - removeCurrent: A Boolean to determine whether to remove existing headers with these keys. Default is `false`.
	/// - Returns: An instance with modified headers.
	func headers(_ headers: HTTPField..., removeCurrent: Bool = false) -> Self {
		self.headers(removeCurrent: removeCurrent) { _ in headers }
	}

	/// Removes a specific HTTP header from the request.
	/// - Parameter field: The key of the header to remove.
	/// - Returns: An instance with the specified header removed.
	func removeHeader(_ field: HTTPField.Name) -> Self {
		modifyRequest {
			$0.headers[field] = nil
		}
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to remove the current header if it exists. Default is `false`.
	/// - Returns: An instance with modified header.
	func header(_ field: HTTPField.Name, _ value: String?, removeCurrent: Bool = false) -> Self {
		if let value {
			return headers(HTTPField(name: field, value: value), removeCurrent: removeCurrent)
		} else {
			return self
		}
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to remove the current header if it exists. Default is `false`.
	/// - Returns: An instance with modified header.
	@_disfavoredOverload
	func header(_ field: HTTPField.Name, _ value: CustomStringConvertible?, removeCurrent: Bool = false) -> Self {
		if let value {
			return headers(HTTPField(name: field, value: value.description), removeCurrent: removeCurrent)
		} else {
			return self
		}
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to remove the current header if it exists. Default is `false`.
	/// - Returns: An instance with modified header.
	func header(_ field: String, _ value: String?, removeCurrent: Bool = false) -> Self {
		if let value {
			return modifyRequest { request in
				guard let name = HTTPField.Name(field) else {
					throw Errors.custom("Invalid header field name '\(field)'")
				}
				if removeCurrent {
					request.headers[fields: name] = [HTTPField(name: name, value: value)]
				} else {
					var field = request.headers[fields: name]
					field.append(HTTPField(name: name, value: value))
					request.headers[fields: name] = field
				}
			}
		} else {
			return self
		}
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to remove the current header if it exists. Default is `false`.
	/// - Returns: An instance with modified header.
	@_disfavoredOverload
	func header(_ field: String, _ value: CustomStringConvertible?, removeCurrent: Bool = false) -> Self {
		header(field, value?.description, removeCurrent: removeCurrent)
	}
}

public extension RequestBuilder where Request == HTTPRequestComponents, Configs == APIClient.Configs {

	/// Adds or updates HTTP headers for the request.
	/// - Parameters:
	///  - headers: An `Encodable` object to be used as headers.
	///  - removeCurrent: A Boolean to determine whether to remove existing headers with these keys. Default is `false`.
	/// - Returns: An instance with modified headers.
	@_disfavoredOverload
	func headers(_ headers: Encodable..., removeCurrent: Bool = false) -> Self {
		self.headers(removeCurrent: removeCurrent) { configs in
			try headers.flatMap { try configs.headersEncoder.encode(AnyEncodable($0)) }
		}
	}
}

// MARK: - Body modifiers

public extension APIClient {

	/// Sets the request body with a specified value and serializer.
	/// - Parameters:
	///   - value: The value to be serialized and set as the body.
	///   - serializer: The `ContentSerializer` used to serialize the body value.
	/// - Returns: An instance with the serialized body.
	func body<T>(_ value: T, as serializer: ContentSerializer<T>) -> Self {
		body {
			try serializer.serialize(value, $0)
		}
		.modifyRequest { req, configs in
			if req.headers[.contentType] == nil {
				req.headers[.contentType] = serializer.contentType(configs).rawValue
			}
		}
	}

	/// Sets the request body with an `Encodable` value.
	/// - Parameter value: The `Encodable` value to set as the body.
	/// - Returns: An instance with the serialized body.
	func body(_ value: any Encodable) -> Self {
		body(AnyEncodable(value), as: .encodable)
	}

	/// Sets the request body with an `Encodable` value.
	/// - Parameter dictionary: The dictionary of encodable values to set as the body.
	/// - Returns: An instance with the serialized body.
	@_disfavoredOverload
	func body(_ dictionary: [String: Encodable?]) -> Self {
		body(dictionary.compactMapValues { $0.map { AnyEncodable($0) } }, as: .encodable)
	}

	/// Sets the request body with a closure that provides `Data`.
	/// - Parameter data: A closure returning the `Data` to be set as the body.
	/// - Returns: An instance with the specified body.
	func body(_ data: @escaping @autoclosure () throws -> Data) -> Self {
		body { _ in try data() }
	}

	/// Sets the request body with a closure that dynamically provides `Data` based on configurations.
	/// - Parameter data: A closure taking `Configs` and returning `Data` to be set as the body.
	/// - Returns: An instance with the specified body.
	func body(_ data: @escaping (Configs) throws -> Data) -> Self {
		modifyRequest { request, configs in
			request.body = try .data(data(configs))
		}
	}

	/// Sets the request body stream with a file URL.
	/// - Parameter file: The file URL to set as the body stream.
	/// - Returns: An instance with the specified body stream.
	func body(file url: URL) -> Self {
		modifyRequest { request, _ in
			request.body = .file(url)
		}
	}
}

// MARK: - Query modifiers

public extension RequestBuilder where Request == HTTPRequestComponents {

	/// Adds URL query parameters using a closure providing an array of `URLQueryItem`.
	/// - Parameters:
	///   - items: A closure returning an array of `URLQueryItem` to be set as query parameters.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	func query(_ items: @escaping @autoclosure () throws -> [URLQueryItem], percentEncoded: Bool = false) -> Self {
		query(percentEncoded: percentEncoded) { _ in
			try items()
		}
	}

	/// Adds URL query parameters with a closure that dynamically provides an array of `URLQueryItem` based on configurations.
	/// - Parameters:
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	///   - items: A closure taking `Configs` and returning an array of `URLQueryItem`.
	/// - Returns: An instance with set query parameters.
	func query(percentEncoded: Bool = false, _ items: @escaping (Configs) throws -> [URLQueryItem]) -> Self {
		modifyRequest { req, configs in
			try req.addQueryItems(items: items(configs), percentEncoded: percentEncoded)
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the specified query parameter.
	func query(_ field: String, _ value: String?, percentEncoded: Bool = false) -> Self {
		query(value.map { [URLQueryItem(name: field, value: $0)] } ?? [], percentEncoded: percentEncoded)
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `RawRepresentable`.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the specified query parameter.
	func query<R: RawRepresentable>(_ field: String, _ value: R?, percentEncoded: Bool = false) -> Self where R.RawValue == String {
		query(field, value?.rawValue, percentEncoded: percentEncoded)
	}
}

public extension RequestBuilder where Request == HTTPRequestComponents, Configs == APIClient.Configs {

	/// Adds URL query parameters using an `Encodable` object.
	/// - Parameters:
	///   - items: An `Encodable` object to be used as query parameters.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	@_disfavoredOverload
	func query(_ items: any Encodable, percentEncoded: Bool = false) -> Self {
		query(percentEncoded: true) {
			try $0.queryEncoder.encode(items, percentEncoded: !percentEncoded)
		}
	}

	/// Adds URL query parameters using a dictionary of JSON objects.
	/// - Parameters:
	///   - parameters: A dictionary of `String: Encodable?` pairs to be used as query parameters.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with set query parameters.
	func query(_ parameters: [String: Encodable?], percentEncoded: Bool = false) -> Self {
		query(percentEncoded: true) {
			try $0.queryEncoder
				.encode(parameters.compactMapValues { $0.map { AnyEncodable($0) }}, percentEncoded: !percentEncoded)
				.sorted(by: { $0.name < $1.name })
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `Encodable`.
	/// - Returns: An instance with the specified query parameter.
	@_disfavoredOverload
	func query(_ field: String, _ value: Encodable?, percentEncoded: Bool = false) -> Self {
		query([field: value], percentEncoded: percentEncoded)
	}
}

// MARK: - URL modifiers

public extension RequestBuilder where Request == HTTPRequestComponents {

	/// Sets the base URL for the request.
	///
	/// - Parameters:
	///   - newBaseURL: The new base URL to set.
	/// - Returns: An instance with the updated base URL.
	///
	/// - Note: The query, and fragment of the original URL are retained, while those of the new URL are ignored.
	func baseURL(_ newBaseURL: URL) -> Self {
		modifyRequest {
			$0.urlComponents = $0.urlComponents.baseURL(newBaseURL)
		}
	}

	/// Sets the URL for the request.
	/// - Parameter url: The new URL to set.
	/// - Returns: An instance with the updated URL.
	func url(_ url: URL) -> Self {
		urlComponents {
			guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
				throw Errors.custom("Invalid URL \(url.absoluteString) components")
			}
			return components
		}
	}

	/// Sets the URL for the request.
	/// - Parameter url: The new URL string to set.
	/// - Returns: An instance with the updated URL.
	func url(_ url: String) -> Self {
		urlComponents {
			let components: URLComponents?
			#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
			if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
				components = URLComponents(string: url, encodingInvalidCharacters: true)
			} else {
				components = URLComponents(string: url)
			}
			#else
			components = URLComponents(string: url)
			#endif
			guard let components else {
				throw Errors.custom("Invalid URL \(url) components")
			}
			return components
		}
	}

	/// Sets the URL components for the request.
	/// - Parameter components: The new URL components to set.
	/// - Returns: An instance with the updated URL.
	func urlComponents(_ components: URLComponents) -> Self {
		urlComponents { components }
	}

	/// Sets the URL components for the request.
	/// - Parameter components: The new URL components to set.
	/// - Returns: An instance with the updated URL.
	func urlComponents(_ components: @escaping () throws -> URLComponents) -> Self {
		modifyRequest {
			$0.urlComponents = try components()
		}
	}

	/// Sets the scheme for the request.
	///
	/// - Parameter scheme: The new scheme to set.
	/// - Returns: An instance with the updated scheme.
	func scheme(_ scheme: String) -> Self {
		modifyRequest {
			$0.urlComponents.scheme = scheme
		}
	}

	/// Sets the host for the request.
	///
	/// - Parameters:
	///   - host: The new host to set.
	///   - percentEncoded: A Boolean to determine whether to percent encode the components. Default is `false`.
	/// - Returns: An instance with the updated host.
	func host(_ host: String, percentEncoded: Bool = false) -> Self {
		modifyRequest {
			$0 = $0.host(host, percentEncoded: percentEncoded)
		}
	}

	/// Sets the port for the request.
	///
	/// - Parameter port: The new port to set.
	/// - Returns: An instance with the updated port.
	func port(_ port: Int?) -> Self {
		modifyRequest {
			$0.urlComponents.port = port
		}
	}

	/// Sets the fragment for the request url.
	///
	/// - Parameter fragment: The new fragment to set.
	/// - Returns: An instance with the updated port.
	func fragment(_ fragment: String?) -> Self {
		modifyRequest {
			$0.urlComponents.fragment = fragment
		}
	}
}
