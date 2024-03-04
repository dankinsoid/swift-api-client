//import Foundation
//
//public extension ContentEncoder where Self == MultipartFormDataEncoder {
//
//	/// A static property to get a `MultipartFormDataEncoder` instance with a default boundary.
//	static var multipartFormData: Self {
//		multipartFormData()
//	}
//
//	/// Creates and returns a `MultipartFormDataEncoder` with an optional custom boundary.
//	/// - Parameter boundary: An optional string specifying the boundary. If `nil`, a default boundary is used.
//	/// - Returns: An instance of `MultipartFormDataEncoder` configured with the specified boundary.
//	static func multipartFormData(boundary: String? = nil) -> Self {
//		MultipartFormDataEncoder(boundary: boundary ?? defaultBoundary)
//	}
//}
//
//public struct MultipartFormDataEncoder: ContentEncoder {
//
//	/// The content type associated with this encoder, which is `multipart/form-data`.
//	public var contentType: ContentType {
//		.multipart(.formData)
//	}
//
//	/// The boundary used to separate parts of the multipart/form-data.
//	public var boundary = defaultBoundary
//
//	/// Encodes the given `Encodable` value into `multipart/form-data` format.
//	/// - Parameter value: The `Encodable` value to encode.
//	/// - Throws: An `Error` if encoding fails.
//	/// - Returns: The encoded data as `Data`.
//	public func encode(_ value: some Encodable) throws -> Data {
//		let params = try URLQueryEncoder().encode(value)
//		return try MultipartFormData.Builder.build(
//			with: params.map {
//				(
//					name: $0.name,
//					filename: nil,
//					mimeType: nil,
//					data: $0.value?.data(using: .utf8) ?? Data()
//				)
//			},
//			willSeparateBy: boundary
//		).body
//	}
//}
//
//let defaultBoundary = "boundary." + RandomBoundaryGenerator.generate()
