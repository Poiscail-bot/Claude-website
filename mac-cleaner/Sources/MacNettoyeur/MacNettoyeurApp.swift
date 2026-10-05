import AppKit
import SwiftUI

@main
struct MacNettoyeurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup("MacNettoyeur") {
            ContentView()
                .environment(state)
                .frame(minWidth: 960, minHeight: 620)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nécessaire quand l'exécutable est lancé hors d'un bundle .app (swift run).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard, junk, largeFiles, uninstaller, startup, security

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Tableau de bord"
        case .junk: return "Nettoyage"
        case .largeFiles: return "Gros fichiers"
        case .uninstaller: return "Désinstallation"
        case .startup: return "Démarrage"
        case .security: return "Sécurité"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .junk: return "sparkles"
        case .largeFiles: return "doc.on.doc"
        case .uninstaller: return "xmark.app"
        case .startup: return "power"
        case .security: return "checkmark.shield"
        }
    }
}

@MainActor
@Observable
final class AppState {
    var section: SidebarSection? = .dashboard
    let junk = JunkModel()
    let largeFiles = LargeFilesModel()
    let uninstaller = UninstallerModel()
    let startup = StartupModel()
    let security = SecurityModel()
}
