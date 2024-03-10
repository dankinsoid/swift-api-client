import Foundation

public extension NetworkClient.Configs {

	/// The redirect behaviour for the client. Default is `.follow`.
	var redirectBehaviour: RedirectBehaviour {
		get { self[\.redirectBehaviour] ?? .follow }
		set { self[\.redirectBehaviour] = newValue }
	}
}

public extension NetworkClient {

	/// Sets the redirect behaviour for the client. Default is `.follow`.
	/// - Note: Redirect behaviour is only applicable to  clients that use `URLSession`.
	func redirect(behaviour: RedirectBehaviour) -> Self {
		configs(\.redirectBehaviour, behaviour)
	}
}
