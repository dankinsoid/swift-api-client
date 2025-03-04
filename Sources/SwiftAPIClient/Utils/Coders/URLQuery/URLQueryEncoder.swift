import Foundation

public struct URLQueryEncoder: QueryEncoder {

  public typealias Output = [URLQueryItem]
  public let dateEncodingStrategy: JSONEncoder.DateEncodingStrategy
  public var arrayEncodingStrategy: ArrayEncodingStrategy
  public var nestedEncodingStrategy: NestedEncodingStrategy
  public var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
  public var boolEncodingStrategy: BoolEncodingStrategy

  public init(
    dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
    keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
    arrayEncodingStrategy: ArrayEncodingStrategy = .commaSeparator,
    nestedEncodingStrategy: NestedEncodingStrategy = .brackets,
    boolEncodingStrategy: BoolEncodingStrategy = .literal
  ) {
    self.dateEncodingStrategy = dateEncodingStrategy
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
    let encoder = _URLQueryEncoder(path: [], context: self)
    let query = try encoder.encode(value)
    return try getQueryItems(from: query, value: value, percentEncoded: percentEncoded)
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

  public enum ArrayEncodingStrategy: CustomStringConvertible {

    /// value1,value2
    case separator(String)
    /// key[0]=value1&key[1]=value2
    case brackets(indexed: Bool)
    /// No brackets are appended. The key is encoded as is and repeated for each value.
    case repeatKey
    case custom((_ path: [CodingKey], _ string: [String]) throws -> String)

    /// value1,value2
    public static var commaSeparator: Self {
      .separator(",")
    }

    public var description: String {
      switch self {
      case let .separator(separator):
        return "separator(\(separator))"
      case let .brackets(indexed):
        return "brackets(indexed: \(indexed))"
      case .repeatKey:
        return "repeatKey"
      case .custom:
        return "custom"
      }
    }
  }

  public enum BoolEncodingStrategy {

    case numeric, literal
    case custom((_ value: Bool) -> String)
  }

  public enum NestedEncodingStrategy {

    case brackets, dots
    case json(JSONEncoder? = nil, encode: ValueType = .objects)

    public static var json: NestedEncodingStrategy { .json(nil) }

    public enum ValueType {
      case objects, arraysAndObjects
    }
  }

  private func getQueryItems(from output: QueryValue, value: Any, percentEncoded: Bool) throws
    -> [URLQueryItem]
  {
    let array: QueryValue.Keyed
    switch output {
    case .single, .unkeyed, .null:
      throw EncodingError.invalidValue(
        value, EncodingError.Context(codingPath: [], debugDescription: "Expected a keyed value."))
    case let .keyed(dictionary):
      array = try encode(dictionary.map { (.string($0.0), $0.1) })
    }
    return try array.map {
      let name: String
      switch nestedEncodingStrategy {
      case .brackets:
        guard var key = $0.0.first?.value else {
          throw EncodingError.invalidValue(
            $0.1, EncodingError.Context(codingPath: [], debugDescription: "No key found."))
        }
        let chain = $0.0.dropFirst().map(\.value).joined(separator: "][")
        if $0.0.count > 1 {
          key += "[" + chain + "]"
        }
        name = key
      case .dots, .json:
        var result = ""
        let point = String(QueryValue.point)
        var wasInt = false
        for key in $0.0 {
          if key.isInt || wasInt || key.value.isEmpty {
            result += "[\(key.value)]"
            wasInt = true
          } else {
            if !result.isEmpty, result.last != "]" {
              result += point
            }
            result += key.value
          }
        }
        name = result
      }
      if percentEncoded {
        return URLQueryItem(
          name: name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? name,
          value: $0.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? $0.1
        )
      } else {
        return URLQueryItem(name: name, value: $0.1)
      }
    }
  }

  private func encode(_ dictionary: [(QueryValue.Key, QueryValue)], path: [QueryValue.Key] = [])
    throws -> QueryValue.Keyed
  {
    guard !dictionary.isEmpty else { return [] }
    var result: QueryValue.Keyed = []
    for (key, query) in dictionary {
      if case .null = query {
        continue
      }
      let path = path + [key]
      switch query {
      case .null:
        break
      case let .single(value):
        result.append((path, value))
      case let .keyed(array):
        result += try encode(array.map { (.string($0.0), $0.1) }, path: path)
      case let .unkeyed(array):
        result += try encode(array, path: path)
      }
    }
    return result
  }

  private func encode(_ array: [QueryValue], path: [QueryValue.Key]) throws -> QueryValue.Keyed {
    let codingKeysPath = path.map { PlainCodingKey($0.value) }
    switch arrayEncodingStrategy {
    case let .brackets(indexed):
      return try encode(
        array.enumerated().map { (.int(indexed ? "\($0.offset)" : ""), $0.element) },
        path: path
      )
    case .repeatKey:
      guard let key = path.last else {
        throw EncodingError.invalidValue(
          array,
          EncodingError.Context(codingPath: codingKeysPath, debugDescription: "No key found.")
        )
      }
      return try encode(
        array.enumerated().map { (key, $0.element) },
        path: path.dropLast()
      )
    default:
      guard let string = try getString(from: .unkeyed(array), path: codingKeysPath) else {
        return []
      }
      return [(path, string)]
    }
  }

  private func getString(from output: QueryValue, path: [CodingKey]) throws -> String? {
    switch output {
    case let .single(value):
      return value
    case .null:
      return nil
    case let .unkeyed(array):
      switch arrayEncodingStrategy {
      case let .separator(separator):
        return try array.enumerated().compactMap {
          try getString(from: $0.element, path: path + [PlainCodingKey(intValue: $0.offset)])
        }
        .joined(separator: separator)
      case .brackets, .repeatKey:
        throw EncodingError.invalidValue(
          array,
          EncodingError.Context(
            codingPath: path,
            debugDescription:
              "Nested arrays are not allowed for .\(arrayEncodingStrategy) array encoding strategy."
          )
        )
      case let .custom(block):
        return try block(
          [],
          array.enumerated().compactMap {
            try getString(from: $0.element, path: path + [PlainCodingKey(intValue: $0.offset)])
          }
        )
      }
    case .keyed:
      throw EncodingError.invalidValue(
        output,
        EncodingError.Context(
          codingPath: path, debugDescription: "Nested keyed objects are not allowed.")
      )
    }
  }
}

final class _URLQueryEncoder: Encoder {

  var codingPath: [CodingKey]
  let context: URLQueryEncoder
  var userInfo: [CodingUserInfoKey: Any]
  @Ref var result: QueryValue

  convenience init(path: [CodingKey] = [], context: URLQueryEncoder) {
    var value: QueryValue = .keyed([])
    let ref: Ref<QueryValue> = Ref {
      value
    } set: {
      value = $0
    }
    self.init(path: path, context: context, result: ref)
  }

  init(path: [CodingKey] = [], context: URLQueryEncoder, result: Ref<QueryValue>) {
    codingPath = path
    self.context = context
    userInfo = [:]
    _result = result
  }

  func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    let container = URLQueryKeyedEncodingContainer<Key>(
      codingPath: codingPath,
      encoder: self,
      result: Ref(self, \.result.keyed)
    )
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    URLQuerySingleValueEncodingContainer(
      isSingle: false,
      codingPath: codingPath,
      encoder: self,
      result: Ref(self, \.result)
    )
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    URLQuerySingleValueEncodingContainer(
      isSingle: true,
      codingPath: codingPath,
      encoder: self,
      result: Ref(self, \.result)
    )
  }

  @discardableResult
  func encode(_ value: Encodable) throws -> QueryValue {
    let isArrayEncoder = IsArrayEncoder(codingPath: codingPath)
    try? value.encode(to: isArrayEncoder)
    let isArray = isArrayEncoder.isArray ?? false
    let isSingle = isArrayEncoder.isSingle ?? false
    if !isSingle,
      case let .json(jsonEncoder, encodeType) = context.nestedEncodingStrategy,
      !codingPath.isEmpty,
      !(codingPath.count < 2 && isArray && encodeType == .objects)
    {
      let jsonEncoder =
        jsonEncoder
        ?? {
          let encoder = JSONEncoder()
          encoder.dateEncodingStrategy = context.dateEncodingStrategy
          encoder.keyEncodingStrategy = context.keyEncodingStrategy
          return encoder
        }()
      let data = try jsonEncoder.encode(value)
      guard let string = String(data: data, encoding: .utf8) else {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "The encoded data is not a valid UTF-8 string"
          )
        )
      }
      result = .single(string)
    } else if let date = value as? Date {
      try context.dateEncodingStrategy.encode(date, encoder: self)
    } else if let decimal = value as? Decimal {
      result = .single(decimal.description)
    } else if let url = value as? URL {
      result = .single(url.absoluteString)
    } else if let url = value as? Data {
      result = .single(url.base64EncodedString())
    } else {
      try value.encode(to: self)
    }
    return result
  }
}

private struct URLQuerySingleValueEncodingContainer: SingleValueEncodingContainer,
  UnkeyedEncodingContainer
{

  var count: Int { 1 }
  let isSingle: Bool
  var codingPath: [CodingKey]
  var encoder: _URLQueryEncoder
  @Ref var result: QueryValue

  mutating func encodeNil() throws {
    append(.null)
  }

  mutating func encode(_ value: Bool) throws {
    append(encoder.context.boolEncodingStrategy.encode(value))
  }

  mutating func encode(_ value: String) throws {
    append(value)
  }

  mutating func encode(_ value: Double) throws {
    append("\(value)")
  }

  mutating func encode(_ value: Float) throws {
    append("\(value)")
  }

  mutating func encode(_ value: Int) throws {
    append("\(value)")
  }

  mutating func encode(_ value: Int8) throws {
    append("\(value)")
  }

  mutating func encode(_ value: Int16) throws {
    append("\(value)")
  }

  mutating func encode(_ value: Int32) throws {
    append("\(value)")
  }

  mutating func encode(_ value: Int64) throws {
    append("\(value)")
  }

  mutating func encode(_ value: UInt) throws {
    append("\(value)")
  }

  mutating func encode(_ value: UInt8) throws {
    append("\(value)")
  }

  mutating func encode(_ value: UInt16) throws {
    append("\(value)")
  }

  mutating func encode(_ value: UInt32) throws {
    append("\(value)")
  }

  mutating func encode(_ value: UInt64) throws {
    append("\(value)")
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let new = try _URLQueryEncoder(
      path: nestedPath(),
      context: encoder.context
    )
    .encode(value)
    append(new)
  }

  mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<
    NestedKey
  > where NestedKey: CodingKey {
    let new: QueryValue = .keyed([])
    append(new)
    let lastIndex = result.unkeyed.count - 1
    let container = URLQueryKeyedEncodingContainer<NestedKey>(
      codingPath: nestedPath(),
      encoder: encoder,
      result: Ref { [$result] in
        $result.wrappedValue.unkeyed[lastIndex].keyed
      } set: { [$result] newValue in
        $result.wrappedValue.unkeyed[lastIndex].keyed = newValue
      }
    )
    return KeyedEncodingContainer(container)
  }

  mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let new = QueryValue.unkeyed([])
    append(new)
    let lastIndex = result.unkeyed.count - 1
    return URLQuerySingleValueEncodingContainer(
      isSingle: false,
      codingPath: nestedPath(),
      encoder: encoder,
      result: Ref { [$result] in
        $result.wrappedValue.unkeyed[lastIndex]
      } set: { [$result] newValue in
        $result.wrappedValue.unkeyed[lastIndex] = newValue
      }
    )
  }

  mutating func superEncoder() -> Encoder {
    if isSingle {
      return _URLQueryEncoder(path: codingPath, context: encoder.context, result: $result)
    } else {
      let new = QueryValue.unkeyed([])
      append(new)
      let lastIndex = result.unkeyed.count - 1
      return _URLQueryEncoder(
        path: nestedPath(),
        context: encoder.context,
        result: Ref { [$result] in
          $result.wrappedValue.unkeyed[lastIndex]
        } set: { [$result] newValue in
          $result.wrappedValue.unkeyed[lastIndex] = newValue
        }
      )
    }
  }

  private func nestedPath() -> [CodingKey] {
    isSingle ? codingPath : codingPath + [PlainCodingKey(intValue: count)]
  }

  func append(_ value: String) {
    append(.single(value))
  }

  func append(_ value: QueryValue) {
    if isSingle {
      result = value
    } else {
      result.unkeyed.append(value)
    }
  }
}

private struct URLQueryKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

  var codingPath: [CodingKey]
  var encoder: _URLQueryEncoder

  @Ref var result: [(String, QueryValue)]

  @inline(__always)
  private func str(_ key: Key) -> String {
    encoder.context.keyEncodingStrategy.encode(key, path: codingPath)
  }

  mutating func encodeNil(forKey key: Key) throws {
    try encode("", forKey: key)
  }

  mutating func encode(_ value: Bool, forKey key: Key) throws {
    append(encoder.context.boolEncodingStrategy.encode(value), forKey: key)
  }

  mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: String, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Double, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Float, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Int, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Int8, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Int16, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Int32, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: Int64, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: UInt, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: UInt8, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: UInt16, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: UInt32, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encode(_ value: UInt64, forKey key: Key) throws {
    append(value.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
    append(value?.description, forKey: key)
  }

  mutating func encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
    guard let value else {
      return
    }
    try encode(value, forKey: key)
  }

  mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
    let encoder = _URLQueryEncoder(
      path: nestedPath(for: key),
      context: encoder.context
    )
    try append(encoder.encode(value), forKey: key)
  }

  mutating func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key)
    -> KeyedEncodingContainer<NestedKey>
  {
    let new: QueryValue = .keyed([])
    let index = result.count
    append(new, forKey: key)
    let container = URLQueryKeyedEncodingContainer<NestedKey>(
      codingPath: nestedPath(for: key),
      encoder: encoder,
      result: Ref { [$result] in
        $result.wrappedValue[index].1.keyed
      } set: { [$result] in
        $result.wrappedValue[index].1.keyed = $0
      }
    )
    return KeyedEncodingContainer(container)
  }

  mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    let new: QueryValue = .unkeyed([])
    let index = result.count
    append(new, forKey: key)
    let container = URLQuerySingleValueEncodingContainer(
      isSingle: false,
      codingPath: nestedPath(for: key),
      encoder: encoder,
      result: Ref { [$result] in
        $result.wrappedValue[index].1
      } set: { [$result] in
        $result.wrappedValue[index].1 = $0
      }
    )
    return container
  }

  mutating func superEncoder() -> Encoder {
    encoder
  }

  mutating func superEncoder(forKey key: Key) -> Encoder {
    let new: QueryValue = .unkeyed([])
    let index = result.count
    append(new, forKey: key)
    return _URLQueryEncoder(
      path: nestedPath(for: key),
      context: encoder.context,
      result: Ref { [$result] in
        $result.wrappedValue[index].1
      } set: { [$result] in
        $result.wrappedValue[index].1 = $0
      }
    )
  }

  private func nestedPath(for key: Key) -> [CodingKey] {
    codingPath + [key]
  }

  @inline(__always)
  private mutating func append(_ value: String?, forKey key: Key) {
    append(value.map { .single($0) } ?? .null, forKey: key)
  }

  @inline(__always)
  private mutating func append(_ value: QueryValue, forKey key: Key) {
    result.append((str(key), value))
  }
}

extension JSONEncoder.KeyEncodingStrategy {

  func encode(_ key: CodingKey, path: [CodingKey]) -> String {
    switch self {
    case .useDefaultKeys:
      return key.stringValue
    case .convertToSnakeCase:
      return key.stringValue.convertToSnakeCase()
    case let .custom(closure):
      return closure(path + [key]).stringValue
    @unknown default:
      return key.stringValue
    }
  }
}

extension JSONEncoder.DateEncodingStrategy {

  func encode(_ date: Date, encoder: Encoder) throws {
    switch self {
    case .deferredToDate:
      try date.encode(to: encoder)
    case .secondsSince1970:
      try date.timeIntervalSince1970.encode(to: encoder)
    case .millisecondsSince1970:
      try (date.timeIntervalSince1970 * 1000).encode(to: encoder)
    case .iso8601:
      try _iso8601Formatter.string(from: date).encode(to: encoder)
    case let .formatted(formatter):
      try formatter.string(from: date).encode(to: encoder)
    case let .custom(closure):
      try closure(date, encoder)
    @unknown default:
      try date.timeIntervalSince1970.encode(to: encoder)
    }
    return
  }
}

extension URLQueryEncoder.BoolEncodingStrategy {

  func encode(_ value: Bool) -> String {
    switch self {
    case .numeric:
      return value ? "1" : "0"
    case .literal:
      return value.description
    case let .custom(closure):
      return closure(value)
    }
  }
}

extension CharacterSet {

  /// Creates a CharacterSet from RFC 3986 allowed characters.
  ///
  /// RFC 3986 states that the following characters are "reserved" characters.
  ///
  /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
  /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
  ///
  /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
  /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
  /// should be percent-escaped in the query string.
  public static let urlQueryAllowedRFC3986: CharacterSet = {
    let encodableDelimiters = CharacterSet(charactersIn: ":#[]@!$&'()*+,;=")
    return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
  }()
}

extension String {

  func convertToSnakeCase() -> String {
    var result = ""
    for (i, char) in enumerated() {
      if char.isUppercase {
        if i != 0 {
          result.append("_")
        }
        result.append(char.lowercased())
      } else {
        result.append(char)
      }
    }
    return result
  }
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private let _iso8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = .withInternetDateTime
  return formatter
}()

private final class IsArrayEncoder: Encoder {

  var isArray: Bool?
  var isSingle: Bool?
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]

  init(codingPath: [CodingKey] = []) {
    self.codingPath = codingPath
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    if isArray == nil {
      isArray = false
    }
    if isSingle == nil {
      isSingle = false
    }
    return KeyedEncodingContainer(MockKeyed())
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    if isArray == nil {
      isArray = true
    }
    if isSingle == nil {
      isSingle = false
    }
    return MockUnkeyed()
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    MockSingle(encoder: self, codingPath: codingPath)
  }

  private struct MockKeyed<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    mutating func encodeNil(forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Bool, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: String, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Double, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Float, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Int, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Int8, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Int16, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Int32, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: Int64, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: UInt, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { throw MockError() }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { throw MockError() }
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
      throw MockError()
    }
    mutating func nestedContainer<NestedKey: CodingKey>(
      keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> { KeyedEncodingContainer(MockKeyed<NestedKey>()) }
    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
      MockUnkeyed()
    }
    mutating func superEncoder() -> Encoder { IsArrayEncoder() }
    mutating func superEncoder(forKey key: Key) -> Encoder { IsArrayEncoder() }
  }

  private struct MockUnkeyed: UnkeyedEncodingContainer {

    var codingPath: [CodingKey] = []
    var count = 0

    mutating func encodeNil() throws { throw MockError() }
    mutating func encode(_ value: Bool) throws { throw MockError() }
    mutating func encode(_ value: String) throws { throw MockError() }
    mutating func encode(_ value: Double) throws { throw MockError() }
    mutating func encode(_ value: Float) throws { throw MockError() }
    mutating func encode(_ value: Int) throws { throw MockError() }
    mutating func encode(_ value: Int8) throws { throw MockError() }
    mutating func encode(_ value: Int16) throws { throw MockError() }
    mutating func encode(_ value: Int32) throws { throw MockError() }
    mutating func encode(_ value: Int64) throws { throw MockError() }
    mutating func encode(_ value: UInt) throws { throw MockError() }
    mutating func encode(_ value: UInt8) throws { throw MockError() }
    mutating func encode(_ value: UInt16) throws { throw MockError() }
    mutating func encode(_ value: UInt32) throws { throw MockError() }
    mutating func encode(_ value: UInt64) throws { throw MockError() }
    mutating func encode<T>(_ value: T) throws where T: Encodable { throw MockError() }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type)
      -> KeyedEncodingContainer<NestedKey>
    { KeyedEncodingContainer(MockKeyed<NestedKey>()) }
    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer { MockUnkeyed() }
    mutating func superEncoder() -> Encoder { IsArrayEncoder() }
  }

  private struct MockSingle: SingleValueEncodingContainer {

    let encoder: IsArrayEncoder
    var codingPath: [CodingKey] = []

    mutating func encodeNil() throws { try throwError() }
    mutating func encode(_ value: Bool) throws { try throwError() }
    mutating func encode(_ value: String) throws { try throwError() }
    mutating func encode(_ value: Double) throws { try throwError() }
    mutating func encode(_ value: Float) throws { try throwError() }
    mutating func encode(_ value: Int) throws { try throwError() }
    mutating func encode(_ value: Int8) throws { try throwError() }
    mutating func encode(_ value: Int16) throws { try throwError() }
    mutating func encode(_ value: Int32) throws { try throwError() }
    mutating func encode(_ value: Int64) throws { try throwError() }
    mutating func encode(_ value: UInt) throws { try throwError() }
    mutating func encode(_ value: UInt8) throws { try throwError() }
    mutating func encode(_ value: UInt16) throws { try throwError() }
    mutating func encode(_ value: UInt32) throws { try throwError() }
    mutating func encode(_ value: UInt64) throws { try throwError() }
    mutating func encode<T>(_ value: T) throws where T: Encodable { try value.encode(to: encoder) }
    private func throwError() throws {
      if encoder.isArray == nil {
        encoder.isArray = false
      }
      if encoder.isSingle == nil {
        encoder.isSingle = true
      }
      throw MockError()
    }
  }
}

private struct MockError: Error {}
