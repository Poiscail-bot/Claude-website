import MacNettoyeurCore
import SwiftUI

@MainActor
@Observable
final class JunkModel {
    private(set) var results: [JunkScanResult] = []
    var selection: Set<URL> = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var currentStep = ""
    private(set) var hasScanned = false
    private(set) var lastReport: CleanReport?

    var totalSize: Int64 { results.reduce(0) { $0 + $1.totalSize } }

    var selectedEntries: [FileEntry] {
        results.flatMap(\.items).filter { selection.contains($0.url) }
    }

    var selectedSize: Int64 { selectedEntries.reduce(0) { $0 + $1.size } }

    var needsFullDiskAccess: Bool { results.contains { $0.accessDenied } }

    func scan() async {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
        lastReport = nil
        var newResults: [JunkScanResult] = []
        var newSelection = Set<URL>()

        for category in JunkCategory.standard() {
            currentStep = category.title
            let result = await Task.detached(priority: .userInitiated) {
                JunkScanner().scan(category)
            }.value
            newResults.append(result)
            if category.selectedByDefault {
                newSelection.formUnion(result.items.map(\.url))
            }
            results = newResults
        }

        selection = newSelection
        hasScanned = true
        isScanning = false
        currentStep = ""
    }

    func clean() async {
        guard !isCleaning, !isScanning else { return }
        isCleaning = true
        var report = CleanReport()

        for result in results {
            let items = result.items.filter { selection.contains($0.url) }
            guard !items.isEmpty else { continue }
            let mode = result.category.deletionMode
            let partial = await Task.detached(priority: .userInitiated) {
                Cleaner().remove(items, mode: mode)
            }.value
            report.merge(partial)
        }

        isCleaning = false
        await scan()
        lastReport = report
    }

    func checkState(of result: JunkScanResult) -> CheckState {
        let selected = result.items.filter { selection.contains($0.url) }.count
        if selected == 0 { return .off }
        return selected == result.items.count ? .on : .mixed
    }

    func toggle(_ result: JunkScanResult) {
        let urls = result.items.map(\.url)
        if checkState(of: result) == .on {
            selection.subtract(urls)
        } else {
            selection.formUnion(urls)
        }
    }

    func toggle(_ item: FileEntry) {
        if selection.contains(item.url) {
            selection.remove(item.url)
        } else {
            selection.insert(item.url)
        }
    }
}

struct JunkView: View {
    @Environment(AppState.self) private var state
    @State private var confirming = false
    @State private var expanded: Set<String> = []

    var body: some View {
        let junk = state.junk
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Nettoyage",
                subtitle: "Caches, journaux et fichiers inutiles",
                symbol: "sparkles"
            )

            if junk.needsFullDiskAccess {
                FullDiskAccessBanner()
            }
            if let report = junk.lastReport {
                ReportBanner(report: report)
            }

            List {
                ForEach(junk.results) { result in
                    DisclosureGroup(isExpanded: expansion(result.id)) {
                        ForEach(result.items) { item in
                            HStack {
                                CheckboxButton(state: junk.selection.contains(item.url) ? .on : .off) {
                                    junk.toggle(item)
                                }
                                Text(item.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text(ByteFormatter.string(item.size))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .contextMenu {
                                Button("Afficher dans le Finder") { SystemActions.reveal([item.url]) }
                            }
                        }
                    } label: {
                        CategoryRow(result: result, state: junk.checkState(of: result)) {
                            junk.toggle(result)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .overlay {
                if junk.results.isEmpty && !junk.isScanning {
                    ContentUnavailableView(
                        "Aucune analyse",
                        systemImage: "sparkles",
                        description: Text("Lancez une analyse pour voir l'espace récupérable.")
                    )
                }
            }

            HStack(spacing: 12) {
                if junk.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Analyse : \(junk.currentStep)…").foregroundStyle(.secondary)
                } else if junk.isCleaning {
                    ProgressView().controlSize(.small)
                    Text("Nettoyage en cours…").foregroundStyle(.secondary)
                } else if junk.hasScanned {
                    Text("Sélection : \(ByteFormatter.string(junk.selectedSize)) sur \(ByteFormatter.string(junk.totalSize))")
                        .font(.callout.weight(.medium))
                }
                Spacer()
                Button(junk.hasScanned ? "Analyser à nouveau" : "Analyser") {
                    Task { await junk.scan() }
                }
                .disabled(junk.isScanning || junk.isCleaning)
                Button("Nettoyer") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(junk.selection.isEmpty || junk.isScanning || junk.isCleaning)
            }
            .controlSize(.large)
        }
        .padding(24)
        .confirmationDialog(
            "Nettoyer \(junk.selection.count) élément(s) (\(ByteFormatter.string(junk.selectedSize))) ?",
            isPresented: $confirming
        ) {
            Button("Nettoyer", role: .destructive) {
                Task { await junk.clean() }
            }
        } message: {
            Text("Les caches, journaux et le contenu de la corbeille sont supprimés définitivement (les apps les recréent si besoin). Les installateurs, pièces jointes et sauvegardes sont placés dans la corbeille.")
        }
    }

    private func expansion(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isExpanded in
                if isExpanded { expanded.insert(id) } else { expanded.remove(id) }
            }
        )
    }
}

private struct CategoryRow: View {
    let result: JunkScanResult
    let state: CheckState
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(state: state, action: toggle)
                .disabled(result.items.isEmpty)
            Image(systemName: result.category.symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(result.category.title).font(.headline)
                    if result.accessDenied {
                        Badge(text: "Accès refusé")
                    }
                    if result.category.deletionMode == .moveToTrash {
                        Badge(text: "Vers la corbeille", tint: .blue)
                    }
                }
                Text(result.category.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(ByteFormatter.string(result.totalSize))
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
