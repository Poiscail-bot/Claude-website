import AppKit
import MacNettoyeurCore
import SwiftUI

@MainActor
@Observable
final class UninstallerModel {
    private(set) var apps: [InstalledApp] = []
    private(set) var isLoading = false
    var selectedApp: URL?
    var searchText = ""
    private(set) var leftovers: [FileEntry] = []
    var leftoverSelection: Set<URL> = []
    private(set) var isUninstalling = false
    var message: String?

    var filteredApps: [InstalledApp] {
        searchText.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var currentApp: InstalledApp? { apps.first { $0.url == selectedApp } }

    var totalToRemove: Int64 {
        (currentApp?.size ?? 0) + leftovers.filter { leftoverSelection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        apps = await Task.detached(priority: .userInitiated) { () -> [InstalledApp] in
            var apps = AppInventory.installedApps(directories: AppInventory.defaultDirectories())
            for index in apps.indices {
                apps[index].size = DiskUsage.allocatedSize(of: apps[index].url)
            }
            return apps
        }.value
        isLoading = false
    }

    func loadLeftovers() async {
        leftovers = []
        leftoverSelection = []
        guard let app = currentApp else { return }
        let found = await Task.detached(priority: .userInitiated) {
            AppInventory.leftovers(for: app)
        }.value
        guard app.url == selectedApp else { return }
        leftovers = found
        leftoverSelection = Set(found.map(\.url))
    }

    func isRunning(_ app: InstalledApp) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func uninstall() async {
        guard let app = currentApp else { return }
        isUninstalling = true
        let entries = [FileEntry(url: app.url, size: app.size)]
            + leftovers.filter { leftoverSelection.contains($0.url) }
        let report = await Task.detached(priority: .userInitiated) {
            Cleaner().remove(entries, mode: .moveToTrash)
        }.value
        isUninstalling = false

        if let failure = report.failures.first(where: { $0.url == app.url }) {
            message = "Impossible de déplacer \(app.name) : \(failure.reason). Si l'app a été installée par un paquet, faites-la glisser dans la corbeille depuis le Finder (mot de passe administrateur)."
        } else {
            apps.removeAll { $0.url == app.url }
            selectedApp = nil
            leftovers = []
            let extra = report.removedCount - 1
            message = "\(app.name) a été placé dans la corbeille avec \(extra) fichier(s) associé(s)."
        }
    }
}

struct UninstallerView: View {
    @Environment(AppState.self) private var state
    @State private var confirming = false

    var body: some View {
        @Bindable var model = state.uninstaller
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Désinstallation",
                subtitle: "Supprimez une app et les fichiers qu'elle laisse dans ~/Library",
                symbol: "xmark.app"
            )

            if let message = model.message {
                HStack {
                    Image(systemName: "info.circle")
                    Text(message).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("OK") { model.message = nil }
                }
                .padding(12)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 8) {
                    TextField("Rechercher une app", text: $model.searchText)
                        .textFieldStyle(.roundedBorder)
                    List(model.filteredApps, selection: $model.selectedApp) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: SystemActions.icon(for: app.url))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name).lineLimit(1)
                                Text(ByteFormatter.string(app.size))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(app.url)
                    }
                    .overlay {
                        if model.isLoading {
                            ProgressView("Inventaire des apps…")
                        }
                    }
                }
                .frame(width: 300)

                detail(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(24)
        .task {
            if model.apps.isEmpty { await model.load() }
        }
        .task(id: model.selectedApp) {
            await model.loadLeftovers()
        }
        .confirmationDialog(
            "Désinstaller \(model.currentApp?.name ?? "") ?",
            isPresented: $confirming
        ) {
            Button("Placer dans la corbeille", role: .destructive) {
                Task { await model.uninstall() }
            }
        } message: {
            Text("L'app et \(model.leftoverSelection.count) fichier(s) associé(s) (\(ByteFormatter.string(model.totalToRemove))) iront dans la corbeille.")
        }
    }

    @ViewBuilder
    private func detail(model: UninstallerModel) -> some View {
        if let app = model.currentApp {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(nsImage: SystemActions.icon(for: app.url))
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.title.bold())
                        Text([app.version.map { "Version \($0)" }, app.bundleID].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                        Text(SystemActions.displayPath(app.url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.isRunning(app) {
                    Label("L'app est ouverte : quittez-la avant de la désinstaller.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.orange)
                }

                Text("Fichiers associés").font(.headline)
                if model.leftovers.isEmpty {
                    Text("Aucun fichier associé trouvé dans ~/Library.")
                        .foregroundStyle(.secondary)
                } else {
                    List(model.leftovers) { entry in
                        HStack {
                            CheckboxButton(state: model.leftoverSelection.contains(entry.url) ? .on : .off) {
                                if model.leftoverSelection.contains(entry.url) {
                                    model.leftoverSelection.remove(entry.url)
                                } else {
                                    model.leftoverSelection.insert(entry.url)
                                }
                            }
                            Text(SystemActions.displayPath(entry.url))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(ByteFormatter.string(entry.size))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .contextMenu {
                            Button("Afficher dans le Finder") { SystemActions.reveal([entry.url]) }
                        }
                    }
                    .frame(minHeight: 160)
                }

                HStack {
                    Text("Total : \(ByteFormatter.string(model.totalToRemove))").font(.headline)
                    Spacer()
                    Button("Désinstaller") { confirming = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(model.isUninstalling || model.isRunning(app))
                }
                .controlSize(.large)
            }
            .card()
        } else {
            ContentUnavailableView(
                "Choisissez une app",
                systemImage: "xmark.app",
                description: Text("Les apps Apple intégrées ne sont pas listées : macOS les protège.")
            )
        }
    }
}
