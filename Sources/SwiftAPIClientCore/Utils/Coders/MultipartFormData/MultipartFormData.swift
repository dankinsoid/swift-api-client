import Foundation

/// RFC 7528 multipart/form-data
/// 4.  Definition of multipart/form-data
///
/// The media type multipart/form-data follows the model of multipart
/// MIME data streams as specified in Section 5.1 of [RFC2046]; changes
/// are noted in this document.
///
/// A multipart/form-data body contains a series of parts separated by a
/// boundary.
public struct MultipartFormData: Hashable {

	public var parts: [Part]

	/// 4.1.  "Boundary" Parameter of multipart/form-data
	///
	/// As with other multipart types, the parts are delimited with a
	/// boundary delimiter, constructed using CRLF, "--", and the value of
	/// the "boundary" parameter.  The boundary is supplied as a "boundary"
	/// parameter to the multipart/form-data type.  As noted in Section 5.1
	/// of [RFC2046], the boundary delimiter MUST NOT appear inside any of
	/// the encapsulated parts, and it is often necessary to enclose the
	/// "boundary" parameter values in quotes in the Content-Type header
	/// field.
	public var boundary: String

	public init(parts: [Part], boundary: String) {
		self.parts = parts
		self.boundary = boundary
	}

	public var data: Data {
		var data = Data()
		let boundaryData = Data(boundary.utf8)
		for part in parts {
			data.append(DASH)
			data.append(boundaryData)
			data.append(CRLF)
			part.write(to: &data)
		}

		data.append(DASH)
		data.append(boundaryData)
		data.append(DASH)
		data.append(CRLF)
		return data
	}
}

public extension MultipartFormData {

	struct Part: Hashable {

		/// Each part MUST contain a Content-Disposition header field [RFC2183]
		/// where the disposition type is "form-data".  The Content-Disposition
		/// header field MUST also contain an additional parameter of "name"; the
		/// value of the "name" parameter is the original field name from the
		/// form (possibly encoded; see Section 5.1).  For example, a part might
		/// contain a header field such as the following, with the body of the
		/// part containing the form data of the "user" field:
		///
		///     Content-Disposition: form-data; name="user"
		///
		public let name: String

		/// For form data that represents the content of a file, a name for the
		/// file SHOULD be supplied as well, by using a "filename" parameter of
		/// the Content-Disposition header field.  The file name isn't mandatory
		/// for cases where the file name isn't available or is meaningless or
		/// private; this might result, for example, when selection or drag-and-
		/// drop is used or when the form data content is streamed directly from
		/// a device.
		public let filename: String?
		public let mimeType: ContentType?
		public let content: Data

		/// RFC 2046 Multipurpose Internet Mail Extensions (MIME) Part Two: Media Types
		/// 5.1.1.  Common Syntax
		///
		/// ...
		///
		/// This Content-Type value indicates that the content consists of one or
		/// more parts, each with a structure that is syntactically identical to
		/// an RFC 822 message, except that the header area is allowed to be
		/// completely empty, and that the parts are each preceded by the line
		///
		///     --gc0pJq0M:08jU534c0p
		///
		/// The boundary delimiter MUST occur at the beginning of a line, i.e.,
		/// following a CRLF, and the initial CRLF is considered to be attached
		/// to the boundary delimiter line rather than part of the preceding
		/// part.  The boundary may be followed by zero or more characters of
		/// linear whitespace. It is then terminated by either another CRLF and
		/// the header fields for the next part, or by two CRLFs, in which case
		/// there are no header fields for the next part.  If no Content-Type
		/// field is present it is assumed to be "message/rfc822" in a
		/// "multipart/digest" and "text/plain" otherwise.
		public func write(to data: inout Data) {
			let header = HTTPField.contentDisposition("form-data", name: name, filename: filename)
			let contentDispositionData = Data(header.description.utf8)

			data.append(contentDispositionData)
			data.append(CRLF)
			if let mimeType {
				let contentTypeHeader = HTTPField.contentType(mimeType)
				let contentTypeData = Data(contentTypeHeader.description.utf8)
				data.append(contentTypeData)
				data.append(CRLF)
			}
			data.append(CRLF)
			data.append(content)
			data.append(CRLF)
		}

		public init(
			name: String,
			filename: String? = nil,
			mimeType: ContentType?,
			data: Data
		) {
			self.name = name
			self.filename = filename
			self.mimeType = mimeType
			content = data
		}
	}
}

private let CRLF: Data = "\r\n".data(using: .ascii)!
private let DASH = "--".data(using: .utf8)!
