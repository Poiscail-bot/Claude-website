import MacNettoyeurCore
import SwiftUI

@MainActor
@Observable
final class LargeFilesModel {
    var minimumSize: Int64 = 100_000_000
    private(set) var files: [LargeFile] = []
    var selection: Set<URL> = []
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var lastReport: CleanReport?
    private var scanTask: Task<[LargeFile], Never>?

    var selectedSize: Int64 {
        files.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func scan() async {
        scanTask?.cancel()
        isScanning = true
        lastReport = nil
        let minimum = minimumSize
        let task = Task.detached(priority: .userInitiated) {
            LargeFileScanner().scan(minimumSize: minimum)
        }
        scanTask = task
        let found = await task.value
        guard scanTask == task else { return }  // Annulée ou remplacée par une analyse plus récente.
        files = found
        selection = []
        hasScanned = true
        isScanning = false
        scanTask = nil
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    func trashSelected() async {
        let entries = files.filter { selection.contains($0.url) }.map(\.entry)
        let report = await Task.detached(priority: .userInitiated) {
            Cleaner().remove(entries, mode: .moveToTrash)
        }.value
        let failed = Set(report.failures.map(\.url))
        let removed = Set(entries.map(\.url)).subtracting(failed)
        files.removeAll { removed.contains($0.url) }
        selection = []
        lastReport = report
    }
}

struct LargeFilesView: View {
    @Environment(AppState.self) private var state
    @State private var confirming = false

    private let sizeOptions: [Int64] = [50_000_000, 100_000_000, 500_000_000, 1_000_000_000]

    var body: some View {
        @Bindable var model = state.largeFiles
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Gros fichiers",
                subtitle: "Les fichiers qui occupent le plus de place dans votre dossier personnel",
                symbol: "doc.on.doc"
            )

            HStack(spacing: 12) {
                Picker("Taille minimale", selection: $model.minimumSize) {
                    ForEach(sizeOptions, id: \.self) { size in
                        Text(ByteFormatter.string(size)).tag(size)
                    }
                }
                .frame(width: 240)
                .disabled(model.isScanning)
                Spacer()
                if model.isScanning {
                    ProgressView().controlSize(.small)
                    Button("Annuler") { model.cancel() }
                } else {
                    Button(model.hasScanned ? "Analyser à nouveau" : "Analyser") {
                        Task { await model.scan() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)

            if let report = model.lastReport {
                ReportBanner(report: report)
            }

            Table(model.files, selection: $model.selection) {
                TableColumn("Nom") { file in
                    HStack(spacing: 8) {
                        Image(nsImage: SystemActions.icon(for: file.url))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(file.url.lastPathComponent).lineLimit(1)
                    }
                }
                TableColumn("Emplacement") { file in
                    Text(SystemActions.displayPath(file.url.deletingLastPathComponent()))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                TableColumn("Modifié") { file in
                    Text(file.modified.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                        .foregroundStyle(.secondary)
                }
                .width(110)
                TableColumn("Taille") { file in
                    Text(ByteFormatter.string(file.size)).monospacedDigit()
                }
                .width(90)
            }
            .contextMenu(forSelectionType: URL.self) { urls in
                Button("Afficher dans le Finder") { SystemActions.reveal(Array(urls)) }
            } primaryAction: { urls in
                SystemActions.reveal(Array(urls))
            }
            .overlay {
                if model.hasScanned && model.files.isEmpty && !model.isScanning {
                    ContentUnavailableView("Aucun gros fichier", systemImage: "checkmark.circle", description: Text("Rien au-dessus du seuil choisi."))
                } else if !model.hasScanned && !model.isScanning {
                    ContentUnavailableView("Aucune analyse", systemImage: "doc.on.doc", description: Text("Choisissez une taille minimale puis lancez l'analyse."))
                }
            }

            HStack {
                Text("\(model.selection.count) sélectionné(s) · \(ByteFormatter.string(model.selectedSize))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Afficher dans le Finder") {
                    SystemActions.reveal(Array(model.selection))
                }
                .disabled(model.selection.isEmpty)
                Button("Mettre à la corbeille") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selection.isEmpty)
            }
            .controlSize(.large)
        }
        .padding(24)
        .confirmationDialog(
            "Placer \(model.selection.count) fichier(s) dans la corbeille ?",
            isPresented: $confirming
        ) {
            Button("Mettre à la corbeille", role: .destructive) {
                Task { await model.trashSelected() }
            }
        } message: {
            Text("Vous pourrez les récupérer tant que la corbeille n'est pas vidée.")
        }
    }
}
