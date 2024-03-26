import Foundation
import SwiftAPIClient

public struct PetStore {

	// MARK: - BaseURL

	var client: APIClient

	public init(baseURL: BaseURL, fileID: String, line: UInt) {
		client = APIClient(baseURL: baseURL.url)
			.fileIDLine(fileID: fileID, line: line)
			.bodyDecoder(PetStoreDecoder())
			.tokenRefresher { refreshToken, client, _ in
				guard let refreshToken else {
					throw Errors.noRefreshToken
				}
				let tokens: Tokens = try await client("auth", "token")
					.body(["refresh_token": refreshToken])
					.post()
				return (tokens.accessToken, tokens.refreshToken, tokens.expiryDate)
			}
	}

	public enum Errors: Error {

		case noRefreshToken
	}
}

// MARK: - "pet" path

public extension PetStore {

  @Path
	struct Pet {
	
		@GET func findByStatus(status: PetStatus) async throws -> PetModel {}

		/// GET /pet/findByStatus
		func findByStatus(_ status: PetStatus, fileID: String = #fileID, line: UInt = #line) async throws -> PetModel {
			try await client.query(["status": status]).post(fileID: fileID, line: line)
		}

    @POST("/") func add(@Body pet _: PetModel) async throws {}

		/// POST /pet
		func add(_ pet: PetModel, fileID: String = #fileID, line: UInt = #line) async throws -> PetModel {
			try await client.body(petModel).post(fileID: fileID, line: line)
		}

		@GET func findByStatus(status: PetStatus) -> [PetModel] {}
		@GET func findByTags(tags: [String]) -> [PetModel] {}

		@Path("{id}")
		public struct PetByID {

			@GET func get() async throws -> PetModel

			@GET(PetModel)
			@POST(_ update: (@Query(name: String?, status: PetStatus?)) -> PetModel)
			@DELETE(PetModel)

			@POST(uploadImage: (@Body _ image: Data, @Query additionalMetadata: String? = nil) -> Void) {
				client.headers(.contentType(.application(.octetStream)))
			}
		}
	}
}

// MARK: - "store" path

public extension PetStore {

	@Path("store")
	struct Store {

		@GET(inventory: [String: Int]) { $0.auth(enabled: true) }
		@POST(order: (@Body _ model: OrderModel) -> OrderModel)

		@Path("order", ":id")
		public struct Order {

			@GET public func find() async throws -> OrderModel
			@DELETE public func delete() async throws -> OrderModel
		}
	}
}

// MARK: "user" path

public extension PetStore {

	@Path("user") { $0.auth(enabled: false)) }
	struct User {

		@POST public func create(@Body _ model: UserModel) async throws -> UserModel
		@POST("createWithList") public func createWith(@Body _ list: [UserModel]) async throws
		@GET("login", \SomeType.login) public func login(@Query username: String, @Query password: String) async throws -> String
		@GET("logout") public func logout() async throws

		@Path(":username")
		public struct UserByUsername {

			@GET public func get() async throws -> UserModel
			@PUT public func update(_ model: UserModel) async throws -> UserModel
			@DELETE public func delete() async throws -> UserModel
		}
	}
}
