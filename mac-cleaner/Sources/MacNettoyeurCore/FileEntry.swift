import Foundation

/// Un fichier ou dossier candidat à la suppression, avec sa taille occupée sur le disque.
public struct FileEntry: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64

    public init(url: URL, size: Int64) {
        self.url = url
        self.size = size
    }

    public var name: String { url.lastPathComponent }
}
