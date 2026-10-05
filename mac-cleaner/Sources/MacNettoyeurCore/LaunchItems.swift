import Foundation

/// Agent ou démon launchd qui démarre automatiquement.
public struct LaunchItem: Identifiable, Hashable, Sendable {
    public enum Scope: String, Sendable, CaseIterable {
        case userAgent = "Agents de votre session"
        case systemAgent = "Agents de tous les utilisateurs"
        case daemon = "Démons système"
    }

    public var id: URL { url }
    public let url: URL
    public let label: String
    public let program: String?
    public let scope: Scope
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public let warnings: [String]

    static let unusualPrefixes = ["/tmp/", "/private/tmp/", "/var/tmp/", "/private/var/tmp/", "/Users/Shared/"]
    static let interpreters: Set<String> = [
        "/bin/sh", "/bin/bash", "/bin/zsh", "/usr/bin/osascript", "/usr/bin/python3",
        "/usr/bin/perl", "/usr/bin/ruby", "/usr/bin/curl",
    ]

    public init(url: URL, plist: [String: Any], scope: Scope, fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)) {
        self.url = url
        self.scope = scope
        label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first
        self.program = program
        runAtLoad = plist["RunAtLoad"] as? Bool ?? false
        keepAlive = plist["KeepAlive"] as? Bool ?? (plist["KeepAlive"] != nil)

        var warnings: [String] = []
        if let program {
            if program.hasPrefix("/") && !fileExists(program) {
                warnings.append("Programme introuvable (reste d'une app désinstallée ?)")
            }
            let hiddenComponent = program.split(separator: "/").contains { $0.hasPrefix(".") && $0 != "." && $0 != ".." }
            if Self.unusualPrefixes.contains(where: { program.hasPrefix($0) }) || hiddenComponent {
                warnings.append("Emplacement inhabituel")
            }
            if Self.interpreters.contains(program) {
                warnings.append("Lance un script")
            }
        } else {
            warnings.append("Aucun programme déclaré")
        }
        self.warnings = warnings
    }

    public static func == (lhs: LaunchItem, rhs: LaunchItem) -> Bool { lhs.url == rhs.url }
    public func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

public enum LaunchItemsReader {
    public static func read(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [LaunchItem] {
        let sources: [(URL, LaunchItem.Scope)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .userAgent),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemAgent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .daemon),
        ]

        var items: [LaunchItem] = []
        for (directory, scope) in sources {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for file in files where file.pathExtension == "plist" {
                items.append(LaunchItem(url: file, plist: Plist.dictionary(at: file), scope: scope))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
