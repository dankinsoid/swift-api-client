import Foundation

public struct LoginQuery: Codable {

	public var username: String
	public var password: String
}

public struct UserModel: Codable {

	public var id: Int
	public var username: String
	public var firstName: String
	public var lastName: String
	public var email: String
	public var password: String
	public var phone: String
	public var userStatus: Int
}

public struct OrderModel: Codable {

	public var id: Int
	public var petId: Int
	public var quantity: Int
	public var shipDate: Date
	public var complete: Bool
}

public struct PetModel: Codable {

	public var id: Int
	public var name: String
	public var tag: String?
}

public enum PetStatus: String, Codable {

	case available
	case pending
	case sold
}

public struct Tokens: Codable {

    public var accessToken: String
    public var refreshToken: String
    public var expiryDate: Date
}
