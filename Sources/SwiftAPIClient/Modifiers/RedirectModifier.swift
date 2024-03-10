import Foundation

#if !canImport(FoundationNetworking)
public extension APIClient.Configs {

	/// The redirect behaviour for the client. Default is `.follow`.
	var redirectBehaviour: RedirectBehaviour {
		get { self[\.redirectBehaviour] ?? .follow }
		set { self[\.redirectBehaviour] = newValue }
	}
}

public extension APIClient {

	/// Sets the redirect behaviour for the client. Default is `.follow`.
	/// - Note: Redirect behaviour is only applicable to  clients that use `URLSession`.
	func redirect(behaviour: RedirectBehaviour) -> Self {
		configs(\.redirectBehaviour, behaviour)
	}
}
#endif
