import Foundation

public struct InstalledApp: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let bundleID: String?
    public let version: String?
    public var size: Int64

    public init(url: URL, name: String, bundleID: String?, version: String?, size: Int64 = 0) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.size = size
    }
}

public enum AppInventory {
    public static func defaultDirectories(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
    }

    /// Apps tierces installées. Les apps Apple (com.apple.*) sont exclues : elles sont
    /// protégées par macOS et ne doivent pas être désinstallées ainsi.
    public static func installedApps(directories: [URL]) -> [InstalledApp] {
        var apps: [InstalledApp] = []
        for directory in directories {
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }

            for url in children where url.pathExtension == "app" {
                let info = Plist.dictionary(at: url.appendingPathComponent("Contents/Info.plist"))
                let bundleID = info["CFBundleIdentifier"] as? String
                if let bundleID, bundleID.hasPrefix("com.apple.") { continue }
                apps.append(InstalledApp(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    bundleID: bundleID,
                    version: info["CFBundleShortVersionString"] as? String
                ))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static let leftoverFolders = [
        "Application Support", "Caches", "Preferences", "Containers", "Group Containers",
        "Saved Application State", "HTTPStorages", "WebKit", "Logs", "LaunchAgents",
        "Application Scripts", "Cookies",
    ]
    static let foldersMatchedByName: Set<String> = ["Application Support", "Caches", "Logs"]

    /// Fichiers laissés dans ~/Library par une app (préférences, caches, conteneurs…).
    public static func leftovers(
        for app: InstalledApp,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [FileEntry] {
        guard let bundleID = app.bundleID?.lowercased(), !bundleID.isEmpty else { return [] }
        let appName = app.name.lowercased()
        let library = home.appendingPathComponent("Library")

        var result: [FileEntry] = []
        for folder in leftoverFolders {
            let directory = library.appendingPathComponent(folder)
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: []
            ) else { continue }

            for child in children
            where matches(child.lastPathComponent.lowercased(), bundleID: bundleID, appName: appName, folder: folder) {
                result.append(FileEntry(url: child, size: DiskUsage.allocatedSize(of: child)))
            }
        }
        return result.sorted { $0.size > $1.size }
    }

    static func matches(_ item: String, bundleID: String, appName: String, folder: String) -> Bool {
        // com.editeur.app, com.editeur.app.plist, com.editeur.app.savedState, com.editeur.app.binarycookies…
        if item == bundleID || item.hasPrefix(bundleID + ".") { return true }
        // Group Containers : IDEQUIPE.com.editeur.app
        if folder == "Group Containers" && item.hasSuffix("." + bundleID) { return true }
        // Certaines apps utilisent leur nom ; on exige une égalité stricte pour éviter les faux positifs.
        if foldersMatchedByName.contains(folder) && appName.count >= 4 && item == appName { return true }
        return false
    }
}
