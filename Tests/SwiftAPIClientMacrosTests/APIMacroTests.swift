import SwiftAPIClientMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class APIMacroTests: XCTestCase {

	private let macros: [String: Macro.Type] = [
		"APIRoot": SwiftAPIClientPathMacro.self,
		"API": SwiftAPIClientPathMacro.self,
	]

	func testExpansionAPIRoot() {
		assertRootExpansion(attribute: "APIRoot")
	}

	func testExpansionDeprecatedAPI() {
		assertRootExpansion(attribute: "API")
	}

	private func assertRootExpansion(attribute: String, line: UInt = #line) {
		assertMacroExpansion(
			"""
			@\(attribute)
			struct Pets {
			}
			""",
			expandedSource: """
			struct Pets {

			  public typealias Body<Value> = _APIParameterWrapper<Value>

			  public typealias Query<Value> = _APIParameterWrapper<Value>

			  public var client: APIClient

			  public init(client: APIClient) {
			      self.client = client
			  }
			}
			
			extension Pets: APIClientScope {
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2),
			line: line
		)
	}

	func testExpansionAPIWithInit() {
		assertMacroExpansion(
			"""
			@APIRoot
			struct Pets {
			  init(client: APIClient) {
			    self.client = client
			  }
			}
			""",
			expandedSource: """
			struct Pets {
			  init(client: APIClient) {
			    self.client = client
			  }

			  public typealias Body<Value> = _APIParameterWrapper<Value>

			  public typealias Query<Value> = _APIParameterWrapper<Value>

			  public var client: APIClient
			}
			
			extension Pets: APIClientScope {
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}
}
