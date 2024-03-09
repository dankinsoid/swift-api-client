import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Defines a redirect behaviour.
public enum RedirectorBehaviour {

	/// Follow the redirect as defined in the response.
	case follow

	/// Do not follow the redirect defined in the response.
	case doNotFollow

	/// Modify the redirect request defined in the response.
	case modify((URLRequest, HTTPURLResponse) -> URLRequest?)
}
