import Foundation

public extension ContentEncoder where Self == MultipartFormDataEncoder {

	/// A static property to get a `MultipartFormDataEncoder` instance with a default boundary.
	static var multipartFormData: Self {
		multipartFormData()
	}

	/// Creates and returns a `MultipartFormDataEncoder` with an optional custom boundary.
	/// - Parameter boundary: An optional string specifying the boundary. If `nil`, a default boundary is used.
	/// - Returns: An instance of `MultipartFormDataEncoder` configured with the specified boundary.
	static func multipartFormData(
		boundary: String? = nil,
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: NestedEncodingStrategy = .brackets,
		boolEncodingStrategy: BoolEncodingStrategy = .literal
	) -> Self {
		MultipartFormDataEncoder(
			boundary: boundary,
			dateEncodingStrategy: dateEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			boolEncodingStrategy: boolEncodingStrategy
		)
	}
}

public struct MultipartFormDataEncoder: ContentEncoder {

	/// The content type associated with this encoder, which is `multipart/form-data`.
	public var contentType: SwiftAPIClient.ContentType {
		.multipart(.formData, boundary: boundary)
	}

	/// The boundary used to separate parts of the multipart/form-data.
	public var boundary: String
	private let queryEncoder: URLQueryEncoder

	public init(
		boundary: String? = nil,
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: NestedEncodingStrategy = .brackets,
		boolEncodingStrategy: BoolEncodingStrategy = .literal
	) {
		self.boundary = boundary ?? RandomBoundaryGenerator.defaultBoundary
		queryEncoder = URLQueryEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			boolEncodingStrategy: boolEncodingStrategy
		)
	}

	/// Encodes the given `Encodable` value into `multipart/form-data` format.
	/// - Parameter value: The `Encodable` value to encode.
	/// - Throws: An `Error` if encoding fails.
	/// - Returns: The encoded data as `Data`.
	public func encode(_ value: some Encodable) throws -> Data {
		let params = try queryEncoder.encode(value)
		return MultipartFormData(
			parts: params.map {
				MultipartFormData.Part(
					name: $0.name,
					filename: nil,
					mimeType: nil,
					data: $0.value?.data(using: .utf8) ?? Data()
				)
			},
			boundary: boundary
		).data
	}
}

private enum RandomBoundaryGenerator {

	static let defaultBoundary = "boundary." + RandomBoundaryGenerator.generate()

	static func generate() -> String {
		String(format: "%08x%08x", UInt32.random(in: 0 ... UInt32.max), UInt32.random(in: 0 ... UInt32.max))
	}
}
