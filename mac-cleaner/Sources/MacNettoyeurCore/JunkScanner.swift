import Foundation

public struct JunkScanResult: Identifiable, Sendable {
    public var id: String { category.id }
    public let category: JunkCategory
    /// Éléments triés du plus gros au plus petit.
    public let items: [FileEntry]
    /// Vrai si macOS a refusé la lecture d'au moins une racine (accès complet au disque manquant).
    public let accessDenied: Bool

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

public struct JunkScanner {
    public init() {}

    public func scan(_ category: JunkCategory) -> JunkScanResult {
        var items: [FileEntry] = []
        var accessDenied = false

        for root in category.roots {
            do {
                let children = try FileManager.default.contentsOfDirectory(
                    at: root, includingPropertiesForKeys: nil, options: []
                )
                for child in children where category.matcher.matches(child) {
                    let size = DiskUsage.allocatedSize(of: child)
                    if size > 0 {
                        items.append(FileEntry(url: child, size: size))
                    }
                }
            } catch let error as CocoaError where error.code == .fileReadNoPermission {
                accessDenied = true
            } catch {
                // Dossier absent : rien à nettoyer.
            }
        }

        items.sort { $0.size > $1.size }
        return JunkScanResult(category: category, items: items, accessDenied: accessDenied)
    }
}
