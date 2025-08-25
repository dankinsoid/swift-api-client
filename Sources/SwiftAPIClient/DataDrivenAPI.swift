import HTTPTypes
import HTTPTypesFoundation
import Logging

struct PetsStore {

	struct GetPetByID {

		var path: (Int) -> String = { id in "/pets/\(id)" }
		var method: HTTPRequest.Method = .get

		struct Query: Codable {

			var includeDetails: Bool?
		}
	}
}

typealias EmptyQuery = EmptyStruct
typealias EmptyBody = EmptyStruct

struct EmptyStruct: Codable, Hashable {
	
	init() {}
}

struct AnyRequest {

	var path: [PathComponent]
	var method: HTTPRequest.Method
	var query: Any.Type?
	var body: Any.Type?
//	var headers:
}

func prepare(request: AnyRequest, configs: APIClient) -> APIClient {
	APIClient()
}

enum PathComponent {

	case constant(String)
	case variable(String)
}
