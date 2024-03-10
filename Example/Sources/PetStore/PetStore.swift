import Foundation
import SwiftNetworking

public struct PetStore {

	// MARK: - BaseURL

	var client: APIClient

    public init(baseURL: BaseURL, fileID: String, line: UInt) {
        client = APIClient(baseURL: baseURL.url)
            .fileIDLine(fileID: fileID, line: line)
            .bodyDecoder(PetStoreDecoder())
            .tokenRefresher { client, _ in
                try await client.path("token").post()
            } auth: {
                .bearer(token: $0)
            }
    }
}

// MARK: - "pet" path

public extension PetStore {

	var pet: Pet {
		Pet(client: client("pet"))
	}

	struct Pet {

		var client: APIClient

		public func update(_ pet: PetModel) async throws -> PetModel {
			try await client.body(pet).put()
		}

		public func add(_ pet: PetModel) async throws -> PetModel {
			try await client.body(pet).post()
		}

		public func findBy(status: PetStatus) async throws -> [PetModel] {
			try await client("findByStatus").query("status", status).call()
		}

		public func findBy(tags: [String]) async throws -> [PetModel] {
			try await client("findByTags").query("tags", tags).call()
		}

		public func callAsFunction(_ id: String) -> PetByID {
			PetByID(client: client.path(id))
		}

		public struct PetByID {

			var client: APIClient

			public func get() async throws -> PetModel {
				try await client()
			}

			public func update(name: String?, status: PetStatus?) async throws -> PetModel {
				try await client
					.query(["name": name, "status": status])
					.post()
			}

			public func delete() async throws -> PetModel {
				try await client.delete()
			}

			public func uploadImage(_ image: Data, additionalMetadata: String? = nil) async throws {
				try await client("uploadImage")
					.query("additionalMetadata", additionalMetadata)
					.body(image)
					.headers(.contentType(.application(.octetStream)))
					.post()
			}
		}
	}
}

// MARK: - "store" path

public extension PetStore {

	var store: Store {
		Store(client: client("store").auth(enabled: false))
	}

	struct Store {

		var client: APIClient

		public func inventory() async throws -> [String: Int] {
			try await client("inventory").auth(enabled: true).call()
		}

		public func order(_ model: OrderModel) async throws -> OrderModel {
			try await client("order").body(model).post()
		}

		public func order(_ id: String) -> Order {
			Order(client: client.path("order", id))
		}

		public struct Order {

			var client: APIClient

			public func find() async throws -> OrderModel {
				try await client()
			}

			public func delete() async throws -> OrderModel {
				try await client.delete()
			}
		}
	}
}

// MARK: "user" path

public extension PetStore {

	var user: User {
		User(client: client("user").auth(enabled: false))
	}

	struct User {

		var client: APIClient

		public func create(_ model: UserModel) async throws -> UserModel {
			try await client.body(model).post()
		}

		public func createWith(list: [UserModel]) async throws {
			try await client("createWithList").body(list).post()
		}

		public func login(username: String, password: String) async throws -> String {
			try await client("login")
				.query(LoginQuery(username: username, password: password))
				.call()
		}

		public func logout() async throws {
			try await client("logout").call()
		}

		public func callAsFunction(_ username: String) -> UserByUsername {
			UserByUsername(client: client.path(username))
		}

		public struct UserByUsername {

			var client: APIClient

			public func get() async throws -> UserModel {
				try await client()
			}

			public func update(_ model: UserModel) async throws -> UserModel {
				try await client.body(model).put()
			}

			public func delete() async throws -> UserModel {
				try await client.delete()
			}
		}
	}
}
