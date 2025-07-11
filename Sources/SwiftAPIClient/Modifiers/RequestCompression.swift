#if canImport(zlib)
import Foundation
import zlib
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient {

	/// Compresses outgoing URL request bodies using the `deflate` `Content-Encoding` and adds the
	/// appropriate header.
	///
	/// - Note: Most requests to most APIs are small and so would only be slowed down by applying this adapter. Measure the
	///         size of your request bodies and the performance impact of using this adapter before use. Using this adapter
	///         with already compressed data, such as images, will, at best, have no effect. Additionally, body compression
	///         is a synchronous operation. Finally, not all servers support request
	///         compression, so test with all of your server configurations before deploying.
	///
	/// - Parameters:
	///   - duplicateHeaderBehavior: `DuplicateHeaderBehavior` to use. `.skip` by default.
	///   - shouldCompressBodyData:  Closure which determines whether the outgoing body data should be compressed. `true` by default.
	@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
	func compressRequest(
		duplicateHeaderBehavior: DuplicateHeaderBehavior = .skip,
		shouldCompressBodyData: @escaping (_ bodyData: Data) -> Bool = { _ in true }
	) -> APIClient {
		httpClientMiddleware(
			CompressionMiddleware(
				duplicateHeaderBehavior: duplicateHeaderBehavior,
				shouldCompressBodyData: shouldCompressBodyData
			)
		)
	}
}

private struct CompressionMiddleware: HTTPClientMiddleware {

	let duplicateHeaderBehavior: DuplicateHeaderBehavior
	let shouldCompressBodyData: (_ bodyData: Data) -> Bool

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		// No need to compress unless we have body data. No support for compressing streams.
		guard let body = request.body else {
			return try await next(request, configs)
		}

		guard let data = body.data, shouldCompressBodyData(data) else {
			return try await next(request, configs)
		}

		if request.headers[.contentEncoding] != nil {
			switch duplicateHeaderBehavior {
			case .error:
				throw Errors.duplicateHeader(.contentEncoding)
			case .replace:
				// Header will be replaced once the body data is compressed.
				break
			case .skip:
				return try await next(request, configs)
			}
		}

		var urlRequest = request
		urlRequest.headers[.contentEncoding] = "deflate"
		urlRequest.body = try .data(deflate(data))
		return try await next(urlRequest, configs)
	}
}

private func deflate(_ data: Data) throws -> Data {
	var output = Data([0x78, 0x5E]) // Header
	try output.append((data as NSData).compressed(using: .zlib) as Data)
	var checksum = adler32Checksum(of: data).bigEndian
	output.append(Data(bytes: &checksum, count: MemoryLayout<UInt32>.size))

	return output
}

private func adler32Checksum(of data: Data) -> UInt32 {
	data.withUnsafeBytes { buffer in
		UInt32(adler32(1, buffer.baseAddress, UInt32(buffer.count)))
	}
}

/// Type that determines the action taken when the URL request already has a `Content-Encoding` header.
public enum DuplicateHeaderBehavior {

	/// Throws a `DuplicateHeaderError`. The default.
	case error
	/// Replaces the existing header value with `deflate`.
	case replace
	/// Silently skips compression when the header exists.
	case skip
}
#endif
