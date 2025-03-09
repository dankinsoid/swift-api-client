import Foundation

extension String {
    /// Returns all matches for a regular expression pattern
    func matches(for pattern: String) -> [[String?]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = regex.matches(in: self, range: range)
        
        return matches.map { match in
            return (0..<match.numberOfRanges).map { rangeIndex in
                let range = match.range(at: rangeIndex)
                guard range.location != NSNotFound else { return nil }
                return (self as NSString).substring(with: range)
            }
        }
    }
    
    /// Returns the first match for a regular expression pattern
    func firstMatch(for pattern: String) -> [String?]? {
        return matches(for: pattern).first
    }
}
