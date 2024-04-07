import SwiftAPIClientMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class CallMacroTests: XCTestCase {

	private let macros: [String: Macro.Type] = [
		"Call": SwiftAPIClientCallMacro.self,
		"GET": SwiftAPIClientCallMacro.self,
		"POST": SwiftAPIClientCallMacro.self,
		"PUT": SwiftAPIClientCallMacro.self,
		"DELETE": SwiftAPIClientCallMacro.self,
		"PATCH": SwiftAPIClientCallMacro.self,
	]

	func testExpansionCallMacro() {
		assertMacroExpansion(
			"""
			@Call(.get)
			func pets() -> Pet {
			}
			""",
			expandedSource: """
			func pets() -> Pet {
			}

			func pets(
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .path("pets")
			      .method(.get)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionEmptyGetMacro() {
		assertMacroExpansion(
			"""
			@GET
			func pets() -> Pet {
			}
			""",
			expandedSource: """
			func pets() -> Pet {
			}

			func pets(
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .path("pets")
			      .method(.get)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionGetMacroWithEmptyString() {
		assertMacroExpansion(
			"""
			@GET("/")
			func pets() -> Pet {
			}
			""",
			expandedSource: """
			func pets() -> Pet {
			}

			func pets(
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .method(.get)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionGetMacroWithNonEmptyString() {
		assertMacroExpansion(
			"""
			@GET("/pets/{id:UUID}")
			func pets() -> Pet {
			}
			""",
			expandedSource: """
			func pets() -> Pet {
			}

			func pets(id: UUID,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .path("pets", "\\(id)")
			      .method(.get)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionGetMacroWithBody() {
		assertMacroExpansion(
			"""
			@GET
			func pets(body: PetBody) -> Pet {
			}
			""",
			expandedSource: """
			func pets(body: PetBody) -> Pet {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "Body parameter is not allowed with GET method", line: 1, column: 1)],
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionPostMacroWithNonEmptyString() {
		assertMacroExpansion(
			"""
			@POST
			func pets(body: Pet) -> Pet {
			}
			""",
			expandedSource: """
			func pets(body: Pet) -> Pet {
			}

			func pets(
			  body: Pet,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .path("pets")
			      .method(.post)
			      .body(body)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionGetMacroReturningVoid() {
		assertMacroExpansion(
			"""
			@GET
			func pets() {
			}
			""",
			expandedSource: """
			func pets() {
			}

			func pets(
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws {
			  try await client
			      .path("pets")
			      .method(.get)
			      .call(.http, as: .void, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionPutMacroWithPathParameters() {
		assertMacroExpansion(
			"""
			@PUT("/pets/{id}")
			func updatePet(body: PetUpdateBody) -> Pet {
			}
			""",
			expandedSource: """
			func updatePet(body: PetUpdateBody) -> Pet {
			}

			func updatePet(id: String,
			  body: PetUpdateBody,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .path("pets", "\\(id)")
			      .method(.put)
			      .body(body)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionPatchMacroWithQueryParameters() {
		assertMacroExpansion(
			"""
			@PATCH("/pets/{id}")
			func partiallyUpdatePet(@Query name: String) -> Pet {
			}
			""",
			expandedSource: """
			func partiallyUpdatePet(@Query name: String) -> Pet {
			}

			func partiallyUpdatePet(id: String, name: String,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> Pet {
			  try await client
			      .path("pets", "\\(id)")
			      .method(.patch)
			      .query(["name": name])
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionDeleteMacro() {
		assertMacroExpansion(
			"""
			@DELETE("/pets/{id}")
			func deletePet() {
			}
			""",
			expandedSource: """
			func deletePet() {
			}

			func deletePet(id: String,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws {
			  try await client
			      .path("pets", "\\(id)")
			      .method(.delete)
			      .call(.http, as: .void, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionForFunctionReturningTuple() {
		assertMacroExpansion(
			"""
			@GET("/users/{id}")
			func getUser() -> (User, prefs: Preferences) {
			}
			""",
			expandedSource: """
			func getUser() -> (User, prefs: Preferences) {
			}

			func getUser(id: String,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> GetUserResponse {
			  try await client
			      .path("users", "\\(id)")
			      .method(.get)
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}

			public struct GetUserResponse: Codable, Equatable {
			    public var user: User
			    public var prefs: Preferences
			    public init(user: User, prefs: Preferences) {
			        self.user = user
			        self.prefs = prefs
			    }
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionForFunctionAcceptingTupleAsBody() {
		assertMacroExpansion(
			"""
			@POST("/users")
			func createUser(body: (name: String, email: String)) -> User {
			}
			""",
			expandedSource: """
			func createUser(body: (name: String, email: String)) -> User {
			}

			func createUser(
			  name bodyName: String,
			  email bodyEmail: String,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> User {
			  try await client
			      .path("users")
			      .method(.post)
			      .body(["name": bodyName, "email": bodyEmail])
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}

	func testExpansionForFunctionAcceptingTupleAsQuery() {
		assertMacroExpansion(
			"""
			@GET
			func search(query: (term: String, limit: Int)) -> [Result] {
			}
			""",
			expandedSource: """
			func search(query: (term: String, limit: Int)) -> [Result] {
			}

			func search(
			  term queryTerm: String,
			  limit queryLimit: Int,
			  fileID: String = #fileID,
			  line: UInt = #line
			) async throws -> [Result] {
			  try await client
			      .path("search")
			      .method(.get)
			      .query(["term": queryTerm, "limit": queryLimit])
			      .call(.http, as: .decodable, fileID: fileID, line: line)
			}
			""",
			macros: macros,
			indentationWidth: .spaces(2)
		)
	}
    
    func testCallMacroFuncWithArguments() {
        assertMacroExpansion(
            """
            @GET
            func login(username: String, password: String) {
                client.auth(.basic(username: username, password: password))
            }
            """,
            expandedSource: """
            func login(username: String, password: String) {
                client.auth(.basic(username: username, password: password))
            }
            
            func login(
              username: String,
              password: String,
              fileID: String = #fileID,
              line: UInt = #line
            ) async throws {
              try await
                  client.auth(.basic(username: username, password: password))
                  .path("login")
                  .method(.get)
                  .call(.http, as: .void, fileID: fileID, line: line)
            }
            """,
            macros: macros,
            indentationWidth: .spaces(2)
        )
    }
}
