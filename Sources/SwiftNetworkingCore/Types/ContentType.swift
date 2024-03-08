import Foundation

/// Represents a MIME content type with support for type, subtype, and parameters.
///
/// Example: `.application(.json)` = `application/json`
public struct ContentType: Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible {

	public typealias RawValue = String
	public typealias StringLiteralType = String

	/// A string representation of the content type, including type, subtype, and parameters.
	public var rawValue: String {
		get {
			(["\(type)/\(subtype)"] + parameters.map { "\($0.key)=\($0.value)" }.sorted()).joined(separator: "; ")
		}
		set {
			self = ContentType(rawValue: newValue)
		}
	}

	/// A textual description of the content type.
	public var description: String { rawValue }

	/// The primary type of the content.
	public var type: String

	/// The subtype of the content.
	public var subtype: String

	/// A dictionary of parameters associated with the content type.
	public var parameters: [String: String]

	/// Initializes a new `ContentType` with the specified type, subtype, and optional parameters.
	public init(
		_ type: String,
		_ subtype: String,
		parameters: [String: String] = [:]
	) {
		self.type = type
		self.subtype = subtype
		self.parameters = parameters
	}

	/// Initializes a new `ContentType` from a raw string value.
	public init(rawValue: String) {
		var type = ""
		var index = rawValue.startIndex
		while index < rawValue.endIndex, rawValue[index] != "/" {
			type.append(rawValue[index])
			index = rawValue.index(after: index)
		}
		if index < rawValue.endIndex {
			index = rawValue.index(after: index)
		}

		var subtype = ""
		while index < rawValue.endIndex, rawValue[index] != ";" {
			subtype.append(rawValue[index])
			index = rawValue.index(after: index)
		}

		var parameters: [String: String] = [:]
		while index < rawValue.endIndex {
			index = rawValue.index(after: index)
			guard index < rawValue.endIndex else { break }
			var key = ""
			while index < rawValue.endIndex, rawValue[index] != ";" {
				key.append(rawValue[index])
				index = rawValue.index(after: index)
			}
			var value = ""
			while index < rawValue.endIndex, rawValue[index] != ";" {
				value.append(rawValue[index])
				index = rawValue.index(after: index)
			}
			parameters[key] = value.trimmingCharacters(in: [" ", "\""])
		}
		self.init(
			type.isEmpty ? "*" : type,
			subtype.isEmpty ? "*" : subtype,
			parameters: parameters
		)
	}

	public init(stringLiteral value: String) {
		self.init(rawValue: value)
	}

	public init(_ stringValue: String) {
		self.init(rawValue: stringValue)
	}

	public init(from decoder: Decoder) throws {
		try self.init(rawValue: String(from: decoder))
	}

    public func charset(_ charset: Charset) -> ContentType {
        var result = self
        result.parameters["charset"] = charset.rawValue
        return result
    }
    
	public func encode(to encoder: Encoder) throws {
		try rawValue.encode(to: encoder)
	}
}

public extension ContentType {

	/// Predefined application content types.
    struct Charset: RawRepresentable, ExpressibleByStringLiteral, Hashable {
        
        public var rawValue: String
        
        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }
        
        /// `utf8`
        public static let utf8: Charset = "utf-8"
    }
    
    /// Predefined application content types.
	struct Application: RawRepresentable, ExpressibleByStringLiteral {

		public var rawValue: String

		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		/// `json`
		public static let json: Application = "json"
		/// `schema+json`
		public static let schemaJson: Application = "schema+json"
		/// `schema-instance+json`
		public static let schemaInstanceJson: Application = "schema-instance+json"
		/// `xml`
		public static let xml: Application = "xml"
		/// `octet-stream`
		public static let octetStream: Application = "octet-stream"
		/// `x-www-form-urlencoded`
		public static let urlEncoded: Application = "x-www-form-urlencoded"
	}

	/// Creates a content type for `application` with a specific subtype. You can use a string literal as well.
	/// Example: `application/json`
	static func application(_ subtype: Application) -> ContentType {
		ContentType("application", subtype.rawValue)
	}

	/// Predefined text content types.
	struct Text: RawRepresentable, ExpressibleByStringLiteral {

		public var rawValue: String

		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		/// `plain`
		public static let plain: Text = "plain"
		/// `html`
		public static let html: Text = "html"
	}

	/// Creates a content type for `text` with a specific subtype and optional charset. You can use a string literal as well.
	/// Example: `text/plain`
	static func text(_ subtype: Text) -> ContentType {
		ContentType("text", subtype.rawValue)
	}

	/// Predefined multipart content types.
	struct Multipart: RawRepresentable, ExpressibleByStringLiteral {

		public var rawValue: String

		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}

		public init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		/// `form-data`
		public static let formData: Multipart = "form-data"
		/// `byteranges`
		public static let byteranges: Multipart = "byteranges"
	}

	/// Creates a content type for `multipart` with a specific subtype. You can use a string literal as well.
	/// Example: `multipart/form-data`
	static func multipart(_ subtype: Multipart) -> ContentType {
		ContentType("multipart", subtype.rawValue)
	}

	/// `*/*`
	static let any = ContentType("*", "*")
}
