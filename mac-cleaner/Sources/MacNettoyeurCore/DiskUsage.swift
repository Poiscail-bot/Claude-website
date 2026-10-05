import Foundation

/// Calcule l'espace réellement occupé sur le disque (taille allouée, pas taille logique).
public enum DiskUsage {
    static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    public static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true { return fileSize(values) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let childValues = try? child.resourceValues(forKeys: Set(keys)) {
                total += fileSize(childValues)
            }
        }
        return total
    }

    private static func fileSize(_ values: URLResourceValues) -> Int64 {
        guard values.isRegularFile == true else { return 0 }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
