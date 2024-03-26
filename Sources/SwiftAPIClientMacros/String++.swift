import Foundation

extension String {
    
    var firstLowercased: String {
        isEmpty ? "" : prefix(1).lowercased() + dropFirst()
    }
}
