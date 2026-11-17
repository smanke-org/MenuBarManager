import Foundation

/// Release version numbers ("1.2.10"), compared part by part as numbers.
public enum Version {
    /// True when `candidate` is a later version than `current`. Missing parts count as 0,
    /// so "1.2" equals "1.2.0", and "1.10.0" is newer than "1.9.9".
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
