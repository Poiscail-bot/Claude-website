import Foundation

/// Dernier garde-fou avant toute suppression : n'autorise que des éléments situés
/// dans le dossier personnel (hors dossiers structurels) ou des apps de /Applications.
public enum SafetyGuard {
    static let protectedRelativePaths: Set<String> = [
        "Library", "Library/Caches", "Library/Logs", "Library/Application Support",
        "Library/Preferences", "Library/Containers", "Library/Group Containers",
        "Library/LaunchAgents", "Library/Developer", "Library/Mobile Documents",
        "Library/Mail", "Library/Keychains", "Library/Saved Application State",
        "Applications", "Desktop", "Documents", "Downloads", "Movies", "Music",
        "Pictures", "Public", ".Trash",
    ]
    static let forbiddenRelativePrefixes = ["Library/Keychains/"]

    public static func canDelete(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let name = url.lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", name != "/" else { return false }

        // On résout le dossier parent mais pas l'élément lui-même : supprimer un lien
        // symbolique ne doit jamais être interprété comme supprimer sa cible.
        let parent = normalizedPath(url.deletingLastPathComponent())
        let path = parent == "/" ? "/" + name : parent + "/" + name

        if parent == "/Applications" && name.hasSuffix(".app") { return true }

        let homePath = normalizedPath(home)
        guard path.hasPrefix(homePath + "/") else { return false }

        let relative = String(path.dropFirst(homePath.count + 1))
        if protectedRelativePaths.contains(relative) { return false }
        if forbiddenRelativePrefixes.contains(where: { relative.hasPrefix($0) }) { return false }
        return true
    }

    /// Résout les liens symboliques puis retire le préfixe /private que macOS ajoute
    /// (ou non, selon que le chemin existe) devant /var, /tmp et /etc.
    static func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        for prefix in ["/private/var/", "/private/tmp/", "/private/etc/"] where path.hasPrefix(prefix) {
            return String(path.dropFirst("/private".count))
        }
        return path
    }
}
