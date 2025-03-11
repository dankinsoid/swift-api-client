import Foundation

public struct URLQueryEncoder: QueryEncoder, ParametersEncoderOptions {

	public typealias Output = [URLQueryItem]
	public var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy
	public var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy
	public var arrayEncodingStrategy: SwiftAPIClient.ArrayEncodingStrategy
	public var nestedEncodingStrategy: SwiftAPIClient.NestedEncodingStrategy
	public var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
	public var boolEncodingStrategy: SwiftAPIClient.BoolEncodingStrategy

	public init(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: SwiftAPIClient.ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: SwiftAPIClient.NestedEncodingStrategy = .brackets,
		boolEncodingStrategy: SwiftAPIClient.BoolEncodingStrategy = .literal
	) {
		self.dateEncodingStrategy = dateEncodingStrategy
		self.dataEncodingStrategy = dataEncodingStrategy
		self.arrayEncodingStrategy = arrayEncodingStrategy
		self.nestedEncodingStrategy = nestedEncodingStrategy
		self.keyEncodingStrategy = keyEncodingStrategy
		self.boolEncodingStrategy = boolEncodingStrategy
	}

	public func encode<T: Encodable>(_ value: T, for baseURL: URL) throws -> URL {
		let items = try encode(value)
		guard !items.isEmpty else { return baseURL }
		guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
			throw EncodingError.invalidValue(
				baseURL,
				EncodingError.Context(codingPath: [], debugDescription: "Invalid URL components")
			)
		}
		components.queryItems = (components.queryItems ?? []) + items
		guard let baseURL = components.url else {
			throw EncodingError.invalidValue(
				baseURL,
				EncodingError.Context(codingPath: [], debugDescription: "Invalid URL components")
			)
		}
		return baseURL
	}

	public func encode<T: Encodable>(_ value: T, percentEncoded: Bool = false) throws
		-> [URLQueryItem]
	{
		let encoder = ParametersEncoder(path: [], context: self)
		let query = try encoder.encode(value)
		return try getKeyedItems(from: query, value: value, percentEncoded: percentEncoded) {
			URLQueryItem(name: $0, value: $1)
		}
	}

	public func encodeQuery<T: Encodable>(_ value: T) throws -> String {
		try encode(value, percentEncoded: true)
			.map {
				"\($0.name)=\($0.value ?? "")"
			}
			.joined(separator: "&")
	}

	public func encodeParameters<T: Encodable>(_ value: T) throws -> [String: String] {
		let items = try encode(value)
		var result: [String: String] = [:]
		for item in items {
			result[item.name] = item.value ?? result[item.name]
		}
		return result
	}

	@available(*, deprecated, renamed: "SwiftAPIClient.ArrayEncodingStrategy")
	public typealias ArrayEncodingStrategy = SwiftAPIClient.ArrayEncodingStrategy
	@available(*, deprecated, renamed: "SwiftAPIClient.NestedEncodingStrategy")
	public typealias NestedEncodingStrategy = SwiftAPIClient.NestedEncodingStrategy
	@available(*, deprecated, renamed: "SwiftAPIClient.BoolEncodingStrategy")
	public typealias BoolEncodingStrategy = SwiftAPIClient.BoolEncodingStrategy
}
