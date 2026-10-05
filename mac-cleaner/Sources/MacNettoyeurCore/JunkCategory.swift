import Foundation

public enum DeletionMode: Sendable, Hashable {
    case moveToTrash
    case permanent
}

/// Détermine quels éléments directs d'un dossier racine appartiennent à une catégorie.
public enum ContentMatcher: Sendable, Hashable {
    case all(excluding: Set<String>)
    case extensions(Set<String>)

    func matches(_ url: URL) -> Bool {
        switch self {
        case .all(let excluded):
            return !excluded.contains(url.lastPathComponent)
        case .extensions(let extensions):
            return extensions.contains(url.pathExtension.lowercased())
        }
    }
}

public struct JunkCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbol: String
    public let roots: [URL]
    public let matcher: ContentMatcher
    public let deletionMode: DeletionMode
    public let selectedByDefault: Bool
    public let needsFullDiskAccess: Bool

    public init(
        id: String, title: String, detail: String, symbol: String, roots: [URL],
        matcher: ContentMatcher = .all(excluding: []), deletionMode: DeletionMode,
        selectedByDefault: Bool, needsFullDiskAccess: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.roots = roots
        self.matcher = matcher
        self.deletionMode = deletionMode
        self.selectedByDefault = selectedByDefault
        self.needsFullDiskAccess = needsFullDiskAccess
    }
}

extension JunkCategory {
    /// Caches à ne pas toucher : synchronisation iCloud, téléchargements en arrière-plan, etc.
    static let protectedCacheNames: Set<String> = [
        "CloudKit", "com.apple.bird", "com.apple.containermanagerd", "com.apple.HomeKit",
        "FamilyCircle", "com.apple.ap.adprivacyd", "com.apple.nsurlsessiond",
        "com.local.macnettoyeur",
    ]

    public static func standard(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [JunkCategory] {
        let library = home.appendingPathComponent("Library")
        return [
            JunkCategory(
                id: "user-caches", title: "Caches des applications",
                detail: "Fichiers temporaires que les apps régénèrent automatiquement.",
                symbol: "archivebox", roots: [library.appendingPathComponent("Caches")],
                matcher: .all(excluding: protectedCacheNames),
                deletionMode: .permanent, selectedByDefault: true
            ),
            JunkCategory(
                id: "logs", title: "Journaux",
                detail: "Journaux des applications et rapports de plantage.",
                symbol: "doc.text", roots: [library.appendingPathComponent("Logs")],
                deletionMode: .permanent, selectedByDefault: true
            ),
            JunkCategory(
                id: "xcode", title: "Xcode – données dérivées",
                detail: "Produits de compilation intermédiaires, recréés au prochain build.",
                symbol: "hammer",
                roots: [
                    library.appendingPathComponent("Developer/Xcode/DerivedData"),
                    library.appendingPathComponent("Developer/CoreSimulator/Caches"),
                ],
                deletionMode: .permanent, selectedByDefault: true
            ),
            JunkCategory(
                id: "xcode-device-support", title: "Xcode – symboles d'appareils",
                detail: "Symboles de débogage d'anciennes versions d'iOS/watchOS, retéléchargés si besoin.",
                symbol: "iphone",
                roots: [
                    library.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"),
                    library.appendingPathComponent("Developer/Xcode/watchOS DeviceSupport"),
                ],
                deletionMode: .permanent, selectedByDefault: false
            ),
            JunkCategory(
                id: "dev-caches", title: "Caches de développement",
                detail: "Caches de paquets npm, Yarn et Gradle.",
                symbol: "shippingbox",
                roots: [
                    home.appendingPathComponent(".npm/_cacache"),
                    home.appendingPathComponent(".yarn/berry/cache"),
                    home.appendingPathComponent(".gradle/caches"),
                ],
                deletionMode: .permanent, selectedByDefault: true
            ),
            JunkCategory(
                id: "trash", title: "Corbeille",
                detail: "Éléments déjà dans la corbeille. Suppression définitive.",
                symbol: "trash", roots: [home.appendingPathComponent(".Trash")],
                deletionMode: .permanent, selectedByDefault: true, needsFullDiskAccess: true
            ),
            JunkCategory(
                id: "mail-downloads", title: "Pièces jointes Mail",
                detail: "Copies locales des pièces jointes ouvertes depuis Mail.",
                symbol: "paperclip",
                roots: [library.appendingPathComponent("Containers/com.apple.mail/Data/Library/Mail Downloads")],
                deletionMode: .moveToTrash, selectedByDefault: true, needsFullDiskAccess: true
            ),
            JunkCategory(
                id: "installers", title: "Installateurs téléchargés",
                detail: "Fichiers .dmg, .pkg, .xip et .iso du dossier Téléchargements.",
                symbol: "arrow.down.app", roots: [home.appendingPathComponent("Downloads")],
                matcher: .extensions(["dmg", "pkg", "mpkg", "xip", "iso"]),
                deletionMode: .moveToTrash, selectedByDefault: false
            ),
            JunkCategory(
                id: "ios-backups", title: "Sauvegardes iPhone / iPad",
                detail: "Sauvegardes locales faites par le Finder. Vérifiez qu'elles sont inutiles.",
                symbol: "externaldrive",
                roots: [library.appendingPathComponent("Application Support/MobileSync/Backup")],
                deletionMode: .moveToTrash, selectedByDefault: false, needsFullDiskAccess: true
            ),
        ]
    }
}
