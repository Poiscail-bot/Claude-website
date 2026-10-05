import Foundation

public struct LargeFile: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public let modified: Date?

    public var entry: FileEntry { FileEntry(url: url, size: size) }
}

/// Parcourt le dossier personnel à la recherche de gros fichiers.
/// ~/Library et la corbeille sont exclus (couverts par le nettoyage), ainsi que l'intérieur
/// des paquets (.app, .photoslibrary…) pour ne jamais proposer d'en supprimer un morceau.
public struct LargeFileScanner {
    public var excludedRelativePaths: Set<String> = ["Library", ".Trash"]
    public var limit = 500

    public init() {}

    public func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        minimumSize: Int64
    ) -> [LargeFile] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey,
        ]
        let excluded = Set(excludedRelativePaths.map { home.appendingPathComponent($0).standardizedFileURL.path })

        guard let enumerator = FileManager.default.enumerator(
            at: home,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [LargeFile] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            if excluded.contains(url.standardizedFileURL.path) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            if size >= minimumSize {
                found.append(LargeFile(url: url, size: size, modified: values.contentModificationDate))
            }
        }

        found.sort { $0.size > $1.size }
        return Array(found.prefix(limit))
    }
}
