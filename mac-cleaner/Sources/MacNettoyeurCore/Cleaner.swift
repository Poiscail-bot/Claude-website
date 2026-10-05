import Foundation

public struct CleanFailure: Hashable, Sendable {
    public let url: URL
    public let reason: String
}

public struct CleanReport: Sendable {
    /// Octets supprimés définitivement.
    public var freedBytes: Int64 = 0
    /// Octets déplacés dans la corbeille (libérés seulement quand elle est vidée).
    public var trashedBytes: Int64 = 0
    public var removedCount = 0
    public var failures: [CleanFailure] = []

    public init() {}

    public mutating func merge(_ other: CleanReport) {
        freedBytes += other.freedBytes
        trashedBytes += other.trashedBytes
        removedCount += other.removedCount
        failures += other.failures
    }

    public var summary: String {
        var parts: [String] = []
        if freedBytes > 0 { parts.append("\(ByteFormatter.string(freedBytes)) libérés") }
        if trashedBytes > 0 { parts.append("\(ByteFormatter.string(trashedBytes)) placés dans la corbeille") }
        parts.append("\(removedCount) élément(s) traité(s)")
        if !failures.isEmpty { parts.append("\(failures.count) échec(s)") }
        return parts.joined(separator: " · ")
    }
}

public struct Cleaner {
    private let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    public func remove(_ entries: [FileEntry], mode: DeletionMode) -> CleanReport {
        var report = CleanReport()
        let fileManager = FileManager.default

        for entry in entries {
            guard SafetyGuard.canDelete(entry.url, home: home) else {
                report.failures.append(CleanFailure(url: entry.url, reason: "Emplacement protégé"))
                continue
            }
            do {
                switch mode {
                case .moveToTrash:
                    try fileManager.trashItem(at: entry.url, resultingItemURL: nil)
                    report.trashedBytes += entry.size
                case .permanent:
                    try fileManager.removeItem(at: entry.url)
                    report.freedBytes += entry.size
                }
                report.removedCount += 1
            } catch {
                report.failures.append(CleanFailure(url: entry.url, reason: error.localizedDescription))
            }
        }
        return report
    }
}
