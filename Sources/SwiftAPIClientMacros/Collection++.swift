@preconcurrency import Foundation

extension Collection {

	func first<T>(as map: (Element) throws -> T?) rethrows -> T? {
		for element in self {
			if let mapped = try map(element) {
				return mapped
			}
		}
		return nil
	}
}
