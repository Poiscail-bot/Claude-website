import Foundation

enum Plist {
    static func dictionary(at url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = object as? [String: Any] else { return [:] }
        return dictionary
    }
}
