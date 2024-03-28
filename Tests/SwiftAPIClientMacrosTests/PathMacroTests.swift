import SwiftAPIClientMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class PathMacroTests: XCTestCase {

    private let macros: [String: Macro.Type] = [
        "Path": SwiftAPIClientPathMacro.self
    ]
    
    func testExpansionEmptyPath() {
        assertMacroExpansion(
      """
      @Path
      struct Pets {
      }
      """,
      expandedSource: """
      struct Pets {
      
        public typealias Body<Value> = _APIParameterWrapper<Value>
      
        public typealias Query<Value> = _APIParameterWrapper<Value>
      
        private var client: APIClient
      
        fileprivate init(client: APIClient) {
            self.client = client
        }
      }
      
      /// /pets
      var pets: Pets  {
          Pets (client: client.path("pets"))
      }
      """,
      macros: macros,
      indentationWidth: .spaces(2)
        )
    }
    
    func testExpansionPathWithString() {
        assertMacroExpansion(
      """
      @Path("/some/long", "path", "/")
      struct Pets {
      }
      """,
      expandedSource: """
      struct Pets {
      
        public typealias Body<Value> = _APIParameterWrapper<Value>
      
        public typealias Query<Value> = _APIParameterWrapper<Value>
      
        private var client: APIClient
      
        fileprivate init(client: APIClient) {
            self.client = client
        }
      }
      
      /// /some/long/path
      var pets: Pets  {
          Pets (client: client.path("some", "long", "path"))
      }
      """,
      macros: macros,
      indentationWidth: .spaces(2)
        )
    }
    
    func testExpansionPathWithArguments() {
        assertMacroExpansion(
      """
      @Path("/some/{long}", "path", "{id: UUID}")
      struct Pets {
      }
      """,
      expandedSource: """
      struct Pets {
      
        public typealias Body<Value> = _APIParameterWrapper<Value>
      
        public typealias Query<Value> = _APIParameterWrapper<Value>
      
        private var client: APIClient
      
        fileprivate init(client: APIClient) {
            self.client = client
        }
      }
      
      /// /some/{long}/path/{id: UUID}
      func pets(_ long: String, id: UUID) -> Pets  {
          Pets (client: client.path("some", "\\(long)", "path", "\\(id)"))
      }
      """,
      macros: macros,
      indentationWidth: .spaces(2)
        )
    }
    
    func testExpansionPathWithFunctions() {
        assertMacroExpansion(
      """
      @Path
      struct Pets {
        @GET
        func pet() -> Pet {}
      }
      """,
      expandedSource: """
      struct Pets {
        @GET
        @available(*, unavailable) @APICallFakeBuilder
        func pet() -> Pet {}
      
        public typealias Body<Value> = _APIParameterWrapper<Value>
      
        public typealias Query<Value> = _APIParameterWrapper<Value>
      
        private var client: APIClient
      
        fileprivate init(client: APIClient) {
            self.client = client
        }
      }
      
      /// /pets
      var pets: Pets  {
          Pets (client: client.path("pets"))
      }
      """,
      macros: macros,
      indentationWidth: .spaces(2)
        )
    }
}
