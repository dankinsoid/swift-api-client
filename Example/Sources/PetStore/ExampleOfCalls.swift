import Foundation
import SwiftNetworking

// MARK: - Usage example

func exampleOfAPICalls() async throws {
	_ = try await api().pet("some-id").get()
	_ = try await api().pet.findBy(status: .available)
	_ = try await api().store.inventory()
	_ = try await api().user.logout()
	_ = try await api().user("name").delete()
}

/// In order to get actual #line and #fileID in loggs use the following function instead of variable.
func api(fileID: String = #fileID, line: UInt = #line) -> PetStore {
	PetStore(baseURL: .production, fileID: fileID, line: line)
}
