import Foundation
import SwiftNetworking

struct  PetStoreDecoder: DataDecoder {

	func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let response = try decoder.decode( PetStoreResponse<T>.self, from: data)
		guard let result = response.response, response.success else {
			throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: [], debugDescription: "Server error"))
		}
		return result
	}
}

struct  PetStoreResponse<T: Decodable>: Decodable {

	var success: Bool
	var error: String?
	var response: T?
}
