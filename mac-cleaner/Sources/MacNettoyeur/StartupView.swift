import MacNettoyeurCore
import SwiftUI

@MainActor
@Observable
final class StartupModel {
    private(set) var items: [LaunchItem] = []
    private(set) var hasLoaded = false
    var message: String?

    func load() async {
        items = await Task.detached(priority: .userInitiated) {
            LaunchItemsReader.read()
        }.value
        hasLoaded = true
    }

    /// Décharge l'agent de la session puis place son fichier .plist dans la corbeille.
    func remove(_ item: LaunchItem) async {
        guard item.scope == .userAgent else { return }
        let url = item.url
        let report = await Task.detached(priority: .userInitiated) { () -> CleanReport in
            Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())", url.path])
            return Cleaner().remove([FileEntry(url: url, size: 0)], mode: .moveToTrash)
        }.value
        if let failure = report.failures.first {
            message = "Échec pour \(item.label) : \(failure.reason)"
        } else {
            message = "\(item.label) ne se lancera plus au démarrage (fichier placé dans la corbeille)."
        }
        await load()
    }
}

struct StartupView: View {
    @Environment(AppState.self) private var state
    @State private var pendingRemoval: LaunchItem?

    var body: some View {
        @Bindable var model = state.startup
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Démarrage",
                subtitle: "Programmes lancés automatiquement en arrière-plan",
                symbol: "power"
            )

            HStack(alignment: .top) {
                Text("Les apps ajoutées via « Ouvrir à la connexion » se gèrent dans les Réglages Système. Ici figurent les agents et démons launchd installés par des apps tierces. Ceux de votre session peuvent être retirés ; les autres nécessitent des droits administrateur.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 16)
                Button("Éléments de connexion…") { SystemActions.openLoginItemsSettings() }
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Actualiser")
            }

            if let message = model.message {
                HStack {
                    Image(systemName: "info.circle")
                    Text(message)
                    Spacer()
                    Button("OK") { model.message = nil }
                }
                .padding(12)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            List {
                ForEach(LaunchItem.Scope.allCases, id: \.self) { scope in
                    let items = model.items.filter { $0.scope == scope }
                    Section("\(scope.rawValue) (\(items.count))") {
                        if items.isEmpty {
                            Text("Aucun").foregroundStyle(.secondary)
                        }
                        ForEach(items) { item in
                            LaunchItemRow(item: item) {
                                pendingRemoval = item
                            }
                        }
                    }
                }
            }
            .overlay {
                if !model.hasLoaded { ProgressView() }
            }
        }
        .padding(24)
        .task {
            if !model.hasLoaded { await model.load() }
        }
        .confirmationDialog(
            "Retirer \(pendingRemoval?.label ?? "") du démarrage ?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
        ) {
            Button("Retirer", role: .destructive) {
                if let item = pendingRemoval {
                    Task { await model.remove(item) }
                }
            }
        } message: {
            Text("Le fichier de lancement est placé dans la corbeille. L'app concernée peut le recréer à sa prochaine ouverture.")
        }
    }
}

private struct LaunchItemRow: View {
    let item: LaunchItem
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.warnings.isEmpty ? "gearshape" : "exclamationmark.triangle.fill")
                .foregroundStyle(item.warnings.isEmpty ? Color.secondary : Color.orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.label).font(.body.weight(.medium))
                    if item.runAtLoad { Badge(text: "Au démarrage", tint: .blue) }
                    if item.keepAlive { Badge(text: "Permanent", tint: .purple) }
                }
                Text(item.program ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.warnings.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.warnings, id: \.self) { warning in
                            Badge(text: warning)
                        }
                    }
                }
            }
            Spacer()
            Button {
                SystemActions.reveal([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Afficher dans le Finder")
            if item.scope == .userAgent {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Retirer du démarrage")
            }
        }
        .padding(.vertical, 3)
    }
}
