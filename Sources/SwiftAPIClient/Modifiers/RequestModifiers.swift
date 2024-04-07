import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Path modifiers

public extension APIClient {

	/// Appends path components to the URL of the request.
	/// - Parameter path: A variadic list of components that conform to `CustomStringConvertible`.
	/// - Returns: An instance of `APIClient` with updated path.
	func callAsFunction(_ path: CustomStringConvertible, _ suffix: any CustomStringConvertible...) -> APIClient {
		self.path([path] + suffix)
	}

	/// Appends path components to the URL of the request.
	/// - Parameter components: A variadic list of components that conform to `CustomStringConvertible`.
	/// - Returns: An instance of `APIClient` with updated path.
	func path(_ components: any CustomStringConvertible...) -> APIClient {
		path(components)
	}

	/// Appends an array of path components to the URL of the request.
	/// - Parameter components: An array of components that conform to `CustomStringConvertible`.
	/// - Returns: An instance of `APIClient` with updated path.
	func path(_ components: [any CustomStringConvertible]) -> APIClient {
		modifyRequest {
			guard !components.isEmpty else { return }
			var fullPath = $0.path.map { FullPath($0) } ?? FullPath(path: [])
			fullPath.append(
				path: components.flatMap {
					$0.description.components(separatedBy: ["/"]).filter { !$0.isEmpty }.map {
						$0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0
					}
				}
			)
			$0.path = fullPath.description
		}
	}
}

// MARK: - Method modifiers

public extension APIClient {

	/// Sets the HTTP method for the request.
	/// - Parameter method: The `HTTPRequest.Method` to set for the request.
	/// - Returns: An instance of `APIClient` with the specified HTTP method.
	func method(_ method: HTTPRequest.Method) -> APIClient {
		modifyRequest {
			$0.method = method
		}
	}

	/// Sets the HTTP `GET` method for the request.
	var get: APIClient { method(.get) }
	/// Sets the HTTP `POST` method for the request.
	var post: APIClient { method(.post) }
	/// Sets the HTTP `PUT` method for the request.
	var put: APIClient { method(.put) }
	/// Sets the HTTP `DELETE` method for the request.
	var delete: APIClient { method(.delete) }
	/// Sets the HTTP `PATCH` method for the request.
	var patch: APIClient { method(.patch) }
}

// MARK: - Headers modifiers

public extension APIClient {

	/// Adds or updates HTTP headers for the request.
	/// - Parameters:
	///   - headers: A variadic list of `HTTPField` to set or update.
	///   - removeCurrent: A Boolean to determine whether to remove existing headers with these keys. Default is `false`.
	/// - Returns: An instance of `APIClient` with modified headers.
	func headers(_ headers: HTTPField..., removeCurrent: Bool = false) -> APIClient {
		modifyRequest { request in
			for header in headers {
				if removeCurrent {
					request.headerFields[fields: header.name] = [header]
				} else {
					var field = request.headerFields[fields: header.name]
					field.append(header)
					request.headerFields[fields: header.name] = field
				}
			}
		}
	}

	/// Removes a specific HTTP header from the request.
	/// - Parameter field: The key of the header to remove.
	/// - Returns: An instance of `APIClient` with the specified header removed.
	func removeHeader(_ field: HTTPField.Name) -> APIClient {
		modifyRequest {
			$0.headerFields[field] = nil
		}
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to remove the current header if it exists. Default is `false`.
	/// - Returns: An instance of `APIClient` with modified header.
	func header(_ field: HTTPField.Name, _ value: String, removeCurrent: Bool = false) -> APIClient {
		headers(HTTPField(name: field, value: value), removeCurrent: removeCurrent)
	}

	/// Adds or updates a specific HTTP header for the request.
	/// - Parameters:
	///   - field: The key of the header to add or update.
	///   - value: The value for the header.
	///   - update: A Boolean to determine whether to remove the current header if it exists. Default is `false`.
	/// - Returns: An instance of `APIClient` with modified header.
	@_disfavoredOverload
	func header(_ field: HTTPField.Name, _ value: CustomStringConvertible?, removeCurrent: Bool = false) -> APIClient {
		if let value {
			return headers(HTTPField(name: field, value: value.description), removeCurrent: removeCurrent)
		} else {
			return self
		}
	}
}

// MARK: - Body modifiers

public extension APIClient {

	/// Sets the request body with a specified value and serializer.
	/// - Parameters:
	///   - value: The value to be serialized and set as the body.
	///   - serializer: The `ContentSerializer` used to serialize the body value.
	/// - Returns: An instance of `APIClient` with the serialized body.
	func body<T>(_ value: T, as serializer: ContentSerializer<T>) -> APIClient {
		body {
			try serializer.serialize(value, $0)
		}
		.modifyRequest { req, configs in
			if req.headerFields[.contentType] == nil {
				req.headerFields[.contentType] = serializer.contentType(configs).rawValue
			}
		}
	}

	/// Sets the request body with an `Encodable` value.
	/// - Parameter value: The `Encodable` value to set as the body.
	/// - Returns: An instance of `APIClient` with the serialized body.
	func body(_ value: any Encodable) -> APIClient {
		body(AnyEncodable(value), as: .encodable)
	}

	/// Sets the request body with an `Encodable` value.
	/// - Parameter dictionary: The dictionary of encodable values to set as the body.
	/// - Returns: An instance of `APIClient` with the serialized body.
	@_disfavoredOverload
	func body(_ dictionary: [String: Encodable?]) -> APIClient {
		body(dictionary.compactMapValues { $0.map { AnyEncodable($0) } }, as: .encodable)
	}

	/// Sets the request body with a closure that provides `Data`.
	/// - Parameter data: A closure returning the `Data` to be set as the body.
	/// - Returns: An instance of `APIClient` with the specified body.
	func body(_ data: @escaping @autoclosure () throws -> Data) -> APIClient {
		body { _ in try data() }
	}

	/// Sets the request body with a closure that dynamically provides `Data` based on configurations.
	/// - Parameter data: A closure taking `Configs` and returning `Data` to be set as the body.
	/// - Returns: An instance of `APIClient` with the specified body.
	func body(_ data: @escaping (Configs) throws -> Data) -> APIClient {
		configs(\.body, data)
	}

	/// Sets the request body stream with a file URL.
	/// - Parameter file: The file URL to set as the body stream.
	/// - Returns: An instance of `APIClient` with the specified body stream.
	func body(file url: URL) -> APIClient {
		configs(\.file) { _ in url }
	}
}

public extension APIClient.Configs {

	/// The data sent as the message body of a request, such as for an HTTP POST request.
	var body: ((APIClient.Configs) throws -> Data)? {
		get { self[\.body] ?? nil }
		set { self[\.body] = newValue }
	}
}

// MARK: - Query modifiers

public extension APIClient {

	/// Adds URL query parameters using a closure providing an array of `URLQueryItem`.
	/// - Parameter items: A closure returning an array of `URLQueryItem` to be set as query parameters.
	/// - Returns: An instance of `APIClient` with set query parameters.
	func query(_ items: @escaping @autoclosure () throws -> [URLQueryItem]) -> APIClient {
		query { _ in
			try items()
		}
	}

	/// Adds URL query parameters with a closure that dynamically provides an array of `URLQueryItem` based on configurations.
	/// - Parameter items: A closure taking `Configs` and returning an array of `URLQueryItem`.
	/// - Returns: An instance of `APIClient` with set query parameters.
	func query(_ items: @escaping (Configs) throws -> [URLQueryItem]) -> APIClient {
		modifyRequest { req, configs in
			let items = try items(configs).map {
				URLQueryItem(
					name: $0.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? $0.name,
					value: $0.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986)
				)
			}
			guard !items.isEmpty else { return }
			var fullPath = req.path.map { FullPath($0) } ?? FullPath(path: [])
			fullPath.queryItems += items
			req.path = fullPath.description
		}
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter.
	/// - Returns: An instance of `APIClient` with the specified query parameter.
	func query(_ field: String, _ value: String?) -> APIClient {
		query(value.map { [URLQueryItem(name: field, value: $0)] } ?? [])
	}

	/// Adds a single URL query parameter.
	/// - Parameters:
	///   - field: The field name of the query parameter.
	///   - value: The value of the query parameter, conforming to `RawRepresentable`.
	/// - Returns: An instance of `APIClient` with the specified query parameter.
	func query<R: RawRepresentable>(_ field: String, _ value: R?) -> APIClient where R.RawValue == String {
		query(field, value?.rawValue)
	}

	/// Adds URL query parameters using an `Encodable` object.
	/// - Parameter items: An `Encodable` object to be used as query parameters.
	/// - Returns: An instance of `APIClient` with set query parameters.
	func query(_ items: any Encodable) -> APIClient {
		query {
			try $0.queryEncoder.encode(items)
		}
	}

	/// Adds URL query parameters using a dictionary of JSON objects.
	/// - Parameter json: A dictionary of `String: JSON` pairs to be used as query parameters.
	/// - Returns: An instance of `APIClient` with set query parameters.
	func query(_ parameters: [String: Encodable?]) -> APIClient {
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
	/// - Returns: An instance of `APIClient` with the specified query parameter.
	@_disfavoredOverload
	func query(_ field: String, _ value: Encodable?) -> APIClient {
		query([field: value])
	}
}

// MARK: - URL modifiers

public extension APIClient {

	/// Sets the base URL for the request.
	///
	/// - Parameters:
	///   - newBaseURL: The new base URL to set.
	/// - Returns: An instance of `APIClient` with the updated base URL.
	///
	/// - Note: The path, query, and fragment of the original URL are retained, while those of the new URL are ignored.
	func baseURL(_ newBaseURL: URL) -> APIClient {
		modifyRequest {
			$0.scheme = newBaseURL.scheme
			$0.authority = newBaseURL.host.map {
				$0 + (newBaseURL.port.map { ":\($0)" } ?? "")
			}
		}
	}

	/// Sets the scheme for the request.
	///
	/// - Parameter scheme: The new scheme to set.
	/// - Returns: An instance of `APIClient` with the updated scheme.
	func scheme(_ scheme: String) -> APIClient {
		modifyRequest {
			$0.scheme = scheme
		}
	}

	/// Sets the host for the request.
	///
	/// - Parameter host: The new host to set.
	/// - Returns: An instance of `APIClient` with the updated host.
	func host(_ host: String) -> APIClient {
		modifyRequest {
			guard var authority = $0._authority else {
				$0.authority = host
				return
			}
			authority.host = host
			$0._authority = authority
		}
	}

	/// Sets the port for the request.
	///
	/// - Parameter port: The new port to set.
	/// - Returns: An instance of `APIClient` with the updated port.
	func port(_ port: Int?) -> APIClient {
		modifyRequest {
			guard var authority = $0._authority else {
				if let port {
					$0.authority = ":\(port)"
				}
				return
			}
			authority.port = port
			$0._authority = authority
		}
	}

	/// Sets the userinfo for the request.
	///
	/// - Parameter userinfo: The new userinfo to set.
	/// - Returns: An instance of `APIClient` with the updated port.
	func userinfo(_ userinfo: String?) -> APIClient {
		modifyRequest {
			guard var authority = $0._authority else {
				if let userinfo {
					$0.authority = "\(userinfo)@"
				}
				return
			}
			authority.userinfo = userinfo
			$0._authority = authority
		}
	}

	/// Sets the authority for the request. Authority is a part of the URL that includes the userinfo, host and the port.
	///
	/// - Parameter authority: The new authority to set.
	/// - Returns: An instance of `APIClient` with the updated port.
	func authority(_ authority: String) -> APIClient {
		modifyRequest {
			$0.authority = authority
		}
	}

	/// Sets the fragment for the request url.
	///
	/// - Parameter fragment: The new fragment to set.
	/// - Returns: An instance of `APIClient` with the updated port.
	func fragment(_ fragment: String?) -> APIClient {
		modifyRequest {
			guard fragment != nil || $0.path != nil else { return }
			var fullPath = $0.path.map { FullPath($0) } ?? FullPath(path: [])
			fullPath.fragment = fragment
			$0.path = fullPath.description
		}
	}
}
