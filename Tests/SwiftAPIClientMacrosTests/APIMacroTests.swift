import SwiftAPIClientMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class APIMacroTests: XCTestCase {
    
    private let macros: [String: Macro.Type] = [
        "API": SwiftAPIClientPathMacro.self
    ]
    
    func testExpansionAPI() {
        assertMacroExpansion(
      """
      @API
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
      """,
      macros: macros,
      indentationWidth: .spaces(2)
        )
    }
    
    func testExpansionAPIWithInit() {
        assertMacroExpansion(
      """
      @API
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
      """,
      macros: macros,
      indentationWidth: .spaces(2)
        )
    }
}
