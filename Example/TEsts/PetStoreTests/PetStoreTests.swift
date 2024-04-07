import Foundation
@testable import PetStore
import SwiftAPIClient
import XCTest

final class PetStoreTests: XCTestCase {

    func testRequests() async throws {
        try await print(api().pet.findBy(status: .available))
    }
}
