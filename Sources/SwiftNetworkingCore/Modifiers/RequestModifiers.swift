import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NetworkClient {

	/// Appends path components to the URL of the request.
	/// - Parameter path: A variadic list of components that conform to `CustomStringConvertible`.
	/// - Returns: An instance of `NetworkClient` with updated path.
	func callAsFunction(_ path: CustomStringConvertible, _ suffix: any CustomStringConvertible...) -> NetworkClient {
		self.path([path] + suffix)
	}

	/// Appends path components to the URL of the request.
	/// - Parameter components: A variadic list of components that conform to `CustomStringConvertible`.
	/// - Returns: An instance of `NetworkClient` with updated path.
	func path(_ components: any CustomStringConvertible...) -> NetworkClient {
		path(components)
	}

	/// Appends an array of path components to the URL of the request.
	/// - Parameter components: An array of components that conform to `CustomStringConvertible`.
	/// - Returns: An instance of `NetworkClient` with updated path.
	func path(_ components: [any CustomStringConvertible]) -> NetworkClient {
		modifyRequest {
			for component in components {
				$0.url?.appendPathComponent(component.description)
			}
		}
	}
}

public extension NetworkClient {

	/// Sets the HTTP method for the request.
	/// - Parameter method: The `HTTPMethod` to set for the request.
	/// - Returns: An instance of `NetworkClient` with the specified HTTP method.
	func method(_ method: HTTPMethod) -> NetworkClient {
		modifyRequest {
			$0.method = method
		}
	}

	/// Sets the HTTP `GET` method for the request.
	var get: NetworkClient { method(.get) }
	/// Sets the HTTP `POST` method for the request.
	var post: NetworkClient { method(.post) }
	/// Sets the HTTP `PUT` method for the request.
	var put: NetworkClient { method(.put) }
	/// Sets the HTTP `DELETE` method for the request.
	var delete: NetworkClient { method(.delete) }
	/// Sets the HTTP `PATCH` method for the request.
	var patch: NetworkClient { method(.patch) }
}

public extension NetworkClient {

	/// Adds or updates HTTP headers for the request.
	/// - Parameters:
	///   - headers: A variadic list of `HTTPHeader` to set or update.
	///   - update: A Boolean to determine whether to update existing headers. Default is `false`.
	/// - Returns: An instance of `NetworkClient` with modified headers.
	func headers(_ headers: HTTPHeader..., update: Bool = false) -> NetworkClient {
		modifyRequest {
			for header in headers {
				if update {
					$0.setValue(header.value, forHTTPHeaderField: header.name.rawValue)
				} else {
					$0.addValue(header.value, forHTTPHeaderField: header.name.rawValue)
				}
			}
		}
	}

	/// Removes a specific HTTP header from the request.
	/// - Parameter field: The key of the header to remove.
	/// - Returns: An instance of `NetworkClient` with the specified header removed.
	func removeHeader(_ field: HTTPHeader.Key) -> NetworkClient {
		modifyRequest {
			$0.setValue(nil, forHTTPHeaderField: field.rawValue)
		}
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to update the header if it exists. Default is `false`.
	/// - Returns: An instance of `NetworkClient` with modified header.
	func header(_ field: HTTPHeader.Key, _ value: String, update: Bool = false) -> NetworkClient {
		headers(HTTPHeader(field, value), update: update)
	}
}

public extension NetworkClient {

	/// Sets the request body with a specified value and serializer.
	/// - Parameters:
	///   - value: The value to be serialized and set as the body.
	///   - serializer: The `ContentSerializer` used to serialize the body value.
	/// - Returns: An instance of `NetworkClient` with the serialized body.
	func body<T>(_ value: T, as serializer: ContentSerializer<T>) -> NetworkClient {
		modifyRequest { req, configs in
			let (data, contentType) = try serializer.serialize(value, configs)
			req.httpBodyStream = nil
			req.httpBody = data
			req.setValue(contentType.rawValue, forHTTPHeaderField: HTTPHeader.Key.contentType.rawValue)
		}
	}

	/// Sets the request body with an `Encodable` value.
	/// - Parameter value: The `Encodable` value to set as the body.
	/// - Returns: An instance of `NetworkClient` with the serialized body.
	func body(_ value: any Encodable) -> NetworkClient {
		body(AnyEncodable(value), as: .encodable)
	}

	/// Sets the request body with an `Encodable` value.
	/// - Parameter dictionary: The dictionary of encodable values to set as the body.
	/// - Returns: An instance of `NetworkClient` with the serialized body.
	@_disfavoredOverload
	func body(_ dictionary: [String: Encodable?]) -> NetworkClient {
		body(dictionary.compactMapValues { $0.map { AnyEncodable($0) } }, as: .encodable)
	}

	/// Sets the request body with a closure that provides `Data`.
	/// - Parameter data: A closure returning the `Data` to be set as the body.
	/// - Returns: An instance of `NetworkClient` with the specified body.
	func body(_ data: @escaping @autoclosure () throws -> Data) -> NetworkClient {
		body { _ in try data() }
	}

	/// Sets the request body with a closure that dynamically provides `Data` based on configurations.
	/// - Parameter data: A closure taking `Configs` and returning `Data` to be set as the body.
	/// - Returns: An instance of `NetworkClient` with the specified body.
	func body(_ data: @escaping (Configs) throws -> Data) -> NetworkClient {
		modifyRequest { req, configs in
			req.httpBodyStream = nil
			req.httpBody = try data(configs)
		}
	}
}

public extension NetworkClient {

	/// Sets the request body stream with a specified value and serializer.
	/// - Parameters:
	///   - value: The value to be serialized and set as the body stream.
	///   - serializer: The `ContentSerializer` used to serialize the body stream value.
	/// - Returns: An instance of `NetworkClient` with the serialized body stream.
	func bodyStream<T>(_ value: T, as serializer: ContentSerializer<T>) -> NetworkClient {
		modifyRequest { req, configs in
			let (data, contentType) = try serializer.serialize(value, configs)
			req.httpBodyStream = InputStream(data: data)
			req.httpBody = nil
			req.setValue(contentType.rawValue, forHTTPHeaderField: HTTPHeader.Key.contentType.rawValue)
		}
	}

	/// Sets the request body stream with an `Encodable` value.
	/// - Parameter value: The `Encodable` value to set as the body stream.
	/// - Returns: An instance of `NetworkClient` with the serialized body stream.
	func bodyStream(_ value: any Encodable) -> NetworkClient {
		bodyStream(AnyEncodable(value), as: .encodable)
	}

	/// Sets the request body stream with an `Encodable` value.
	/// - Parameter dictionary: The dictionary of encodable values to set as the body stream.
	/// - Returns: An instance of `NetworkClient` with the serialized body stream.
	@_disfavoredOverload
	func bodyStream(_ dictionary: [String: Encodable?]) -> NetworkClient {
		bodyStream(dictionary.compactMapValues { $0.map { AnyEncodable($0) } }, as: .encodable)
	}

	/// Sets the request body stream with a file URL.
	/// - Parameter file: The file URL to set as the body stream.
	/// - Returns: An instance of `NetworkClient` with the specified body stream.
	func bodyStream(file url: URL) -> NetworkClient {
		bodyStream { _ in
			guard let stream = InputStream(url: url) else {
				throw Errors.invalidFileURL(url)
			}
			return stream
		}
	}

	/// Sets the request body stream with a closure that provides `InputStream`.
	/// - Parameter stream: A closure returning the `InputStream` to be set as the body stream.
	/// - Returns: An instance of `NetworkClient` with the specified body stream.
	func bodyStream(_ stream: @escaping @autoclosure () throws -> InputStream) -> NetworkClient {
		bodyStream { _ in try stream() }
	}

	/// Sets the request body stream with a closure that dynamically provides `InputStream` based on configurations.
	/// - Parameter stream: A closure taking `Configs` and returning `InputStream` to be set as the body stream.
	/// - Returns: An instance of `NetworkClient` with the specified body stream.
	func bodyStream(_ stream: @escaping (Configs) throws -> InputStream) -> NetworkClient {
		modifyRequest { req, configs in
			req.httpBody = nil
			req.httpBodyStream = try stream(configs)
		}
	}
}

public extension NetworkClient {

	/// Adds URL query parameters using a closure providing an array of `URLQueryItem`.
	/// - Parameter items: A closure returning an array of `URLQueryItem` to be set as query parameters.
	/// - Returns: An instance of `NetworkClient` with set query parameters.
	func query(_ items: @escaping @autoclosure () throws -> [URLQueryItem]) -> NetworkClient {
		query { _ in
			try items()
		}
	}

	/// Adds URL query parameters with a closure that dynamically provides an array of `URLQueryItem` based on configurations.
	/// - Parameter items: A closure taking `Configs` and returning an array of `URLQueryItem`.
	/// - Returns: An instance of `NetworkClient` with set query parameters.
	func query(_ items: @escaping (Configs) throws -> [URLQueryItem]) -> NetworkClient {
		modifyRequest { req, configs in
			if
				let url = req.url,
				var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			{
				if components.queryItems == nil {
					components.queryItems = []
				}
				try components.queryItems?.append(contentsOf: items(configs))
				req.url = components.url ?? url
			} else {
				configs.logger.error("Invalid request: \(req)")
			}
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter.
	/// - Returns: An instance of `NetworkClient` with the specified query parameter.
	func query(_ field: String, _ value: String?) -> NetworkClient {
		query(value.map { [URLQueryItem(name: field, value: $0)] } ?? [])
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `RawRepresentable`.
	/// - Returns: An instance of `NetworkClient` with the specified query parameter.
	func query<R: RawRepresentable>(_ field: String, _ value: R?) -> NetworkClient where R.RawValue == String {
		query(field, value?.rawValue)
	}

	/// Adds URL query parameters using an `Encodable` object.
	/// - Parameter items: An `Encodable` object to be used as query parameters.
	/// - Returns: An instance of `NetworkClient` with set query parameters.
	func query(_ items: any Encodable) -> NetworkClient {
		query {
			try $0.queryEncoder.encode(items)
		}
	}

	/// Adds URL query parameters using a dictionary of JSON objects.
	/// - Parameter json: A dictionary of `String: JSON` pairs to be used as query parameters.
	/// - Returns: An instance of `NetworkClient` with set query parameters.
	func query(_ parameters: [String: Encodable?]) -> NetworkClient {
		query {
			try $0.queryEncoder
				.encode(parameters.compactMapValues { $0.map { AnyEncodable($0) }})
				.sorted(by: { $0.name < $1.name })
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `Encodable`.
	/// - Returns: An instance of `NetworkClient` with the specified query parameter.
	@_disfavoredOverload
	func query(_ field: String, _ value: Encodable?) -> NetworkClient {
		query([field: value])
	}
}

public extension NetworkClient {

	/// Sets the base URL for the request.
	///
	/// - Parameters:
	///   - newBaseURL: The new base URL to set.
	/// - Returns: An instance of `NetworkClient` with the updated base URL.
	///
	/// - Note: The path, query, and fragment of the original URL are retained, while those of the new URL are ignored.
	func baseURL(_ newBaseURL: URL) -> NetworkClient {
		modifyURLComponents { components in
			components.scheme = newBaseURL.scheme
			components.host = newBaseURL.host
			components.port = newBaseURL.port
		}
	}

	/// Sets the scheme for the request.
	///
	/// - Parameter scheme: The new scheme to set.
	/// - Returns: An instance of `NetworkClient` with the updated scheme.
	func scheme(_ scheme: String) -> NetworkClient {
		modifyURLComponents { components in
			components.scheme = scheme
		}
	}

	/// Sets the host for the request.
	///
	/// - Parameter host: The new host to set.
	/// - Returns: An instance of `NetworkClient` with the updated host.
	func host(_ host: String) -> NetworkClient {
		modifyURLComponents { components in
			components.host = host
		}
	}

	/// Sets the port for the request.
	///
	/// - Parameter port: The new port to set.
	/// - Returns: An instance of `NetworkClient` with the updated port.
	func port(_ port: Int?) -> NetworkClient {
		modifyURLComponents { components in
			components.port = port
		}
	}
}

public extension NetworkClient {

	/// Modifies the URL components of the request.
	///
	/// - Parameter modifier: A closure that takes the current URL components and modifies them.
	/// - Returns: An instance of `NetworkClient` with the modified URL components.
	func modifyURLComponents(_ modifier: @escaping (inout URLComponents) throws -> Void) -> NetworkClient {
		modifyRequest { req, configs in
			guard let url = req.url else {
				configs.logger.error("Failed to get URL of request")
				return
			}

			guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
				configs.logger.error("Failed to get components of \(url.absoluteString)")
				return
			}

			try modifier(&components)

			guard let newURL = components.url else {
				configs.logger.error("Failed to get URL from components")
				return
			}

			req.url = newURL
		}
	}
}

public extension NetworkClient {

	/// Sets the URLRequest timeoutInterval property.
	/// - Parameter timeout: The timeout interval to set for the request.
	/// - Returns: An instance of `NetworkClient` with the specified timeout interval.
	func timeoutInterval(_ timeout: TimeInterval) -> NetworkClient {
		modifyRequest {
			$0.timeoutInterval = timeout
		}
	}
}

public extension NetworkClient {

	/// Sets the URLRequest cachePolicy property.
	/// - Parameter policy: The cache policy to set for the request.
	/// - Returns: An instance of `NetworkClient` with the specified cache policy.
	func cachePolicy(_ policy: URLRequest.CachePolicy) -> NetworkClient {
		modifyRequest {
			$0.cachePolicy = policy
		}
	}
}
