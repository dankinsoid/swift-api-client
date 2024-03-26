import Foundation
import SwiftAPIClient

@API
public struct PetStore {

	// MARK: - BaseURL

	public init(baseURL: BaseURL) {
		client = APIClient(baseURL: baseURL.url)
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
}

// MARK: - "pet" path

public extension PetStore {

	@Path
	struct Pet {

		@PUT("/") public func update(_: PetModel) -> PetModel {}
		@POST("/") public func add(_: PetModel) -> PetModel {}
		@GET public func findByStatus(@Query _ status: PetStatus) -> [PetModel] {}
		@GET public func findByTags(@Query _ tags: [String]) -> [PetModel] {}

		@Path("{id}")
		public struct PetByID {

			#GET(PetModel)
			#DELETE
			@POST("/") public func update(@Query name: String?, @Query status: PetStatus?) -> PetModel {}
			@POST public func uploadImage(_ body: Data, @Query additionalMetadata: String? = nil) {}
		}
	}
}

// MARK: - "store" path

public extension PetStore {

	@Path
	struct Store {

		init(client: APIClient) {
			self.client = client.auth(enabled: false)
		}

		@GET public func inventory() -> [String: Int] { client.auth(enabled: true) }
		@POST public func order(_: OrderModel) -> OrderModel {}

		@Path("order", "{id}")
		public struct Order {

			#GET(OrderModel)
			#DELETE(OrderModel)
		}
	}
}

// MARK: "user" path

extension PetStore {

	@Path
	struct User {

		init(client: APIClient) {
			self.client = client.auth(enabled: false)
		}

		@POST public func create(_: UserModel) -> UserModel {}
		@POST public func createWithList(_: [UserModel]) {}
		@GET public func login(username: String, password: String) -> String {
			client.headers(.authorization(username: username, password: password))
		}

		@GET public func logout() {}

		@Path("{username}")
		public struct UserByUsername {

			#GET(UserModel)
			#DELETE(UserModel)
			@PUT("/") public func update(_: UserModel) -> UserModel {}
		}
	}
}

private enum Errors: Error {
	case noRefreshToken
}
