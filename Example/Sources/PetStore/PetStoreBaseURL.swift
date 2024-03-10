import Foundation
import SwiftNetworking

public extension PetStore {

	// MARK: - BaseURL

	enum BaseURL: String {

		case production = "https://petstore.com"
		case staging = "https://staging.petstore.com"
		case test = "http://localhost:8080"

		public var url: URL { URL(string: rawValue)! }
	}
}
