import Foundation

/// Formate une taille en octets comme le Finder (base 1000, virgule décimale).
public enum ByteFormatter {
    public static func string(_ bytes: Int64) -> String {
        guard bytes >= 1000 else { return "\(max(bytes, 0)) o" }
        let units = ["Ko", "Mo", "Go", "To"]
        var value = Double(bytes) / 1000
        var index = 0
        while value >= 1000 && index < units.count - 1 {
            value /= 1000
            index += 1
        }
        let number = String(format: value < 10 ? "%.1f" : "%.0f", value)
            .replacingOccurrences(of: ".", with: ",")
        return "\(number) \(units[index])"
    }
}
