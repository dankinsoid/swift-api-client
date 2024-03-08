import Foundation
import SwiftNetworkingCore

// MARK: - Usage example

func exampleOfAPICalls() async throws {
	_ = try await api().pet("some-id").get()
	_ = try await api().pet.findBy(status: .available)
	_ = try await api().store.inventory()
	_ = try await api().user.logout()
	_ = try await api().user("name").delete()
}

func api(fileID: String = #fileID, line: UInt = #line) -> Petstore {
	Petstore(baseURL: .production, fileID: fileID, line: line)
}
