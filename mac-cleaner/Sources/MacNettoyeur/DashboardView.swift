import Combine
import MacNettoyeurCore
import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var state
    @State private var disk: DiskStats?
    @State private var memory: MemoryStats?
    @State private var load: Double = 0
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        let junk = state.junk
        let cores = SystemStats.cpuCount
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Tableau de bord",
                    subtitle: "Votre Mac allumé depuis \(SystemStats.uptimeDescription)",
                    symbol: "gauge.with.dots.needle.67percent"
                )

                HStack(spacing: 16) {
                    RingCard(
                        title: "Stockage",
                        fraction: disk?.fraction ?? 0,
                        primary: disk.map { "\(ByteFormatter.string($0.available)) disponibles" } ?? "—",
                        secondary: disk.map { "sur \(ByteFormatter.string($0.total))" } ?? "",
                        tint: .blue
                    )
                    RingCard(
                        title: "Mémoire",
                        fraction: memory?.fraction ?? 0,
                        primary: memory.map { "\(ByteFormatter.string(Int64($0.used))) utilisés" } ?? "—",
                        secondary: memory.map { "sur \(ByteFormatter.string(Int64($0.total)))" } ?? "",
                        tint: .purple
                    )
                    RingCard(
                        title: "Processeur",
                        fraction: load / Double(max(cores, 1)),
                        primary: "Charge moyenne \(String(format: "%.1f", load))",
                        secondary: "\(cores) cœurs",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Analyse intelligente", systemImage: "sparkles").font(.title2.bold())
                    Text("Recherche les caches, journaux, données de développement et fichiers temporaires que macOS et vos apps savent régénérer.")
                        .foregroundStyle(.secondary)
                    if junk.hasScanned {
                        Text("\(ByteFormatter.string(junk.totalSize)) trouvés lors de la dernière analyse, dont \(ByteFormatter.string(junk.selectedSize)) sélectionnés.")
                            .font(.callout.weight(.medium))
                    }
                    Button {
                        state.section = .junk
                        Task { await junk.scan() }
                    } label: {
                        Label(junk.isScanning ? "Analyse en cours…" : "Lancer l'analyse", systemImage: "magnifyingglass")
                            .frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(junk.isScanning || junk.isCleaning)
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Label("Bon à savoir", systemImage: "lightbulb").font(.headline)
                    Text("macOS purge déjà les caches quand l'espace manque, et la mémoire « utilisée » est normale : un Mac sain garde sa RAM occupée. Le nettoyage est utile quand le disque est presque plein, pas comme rituel quotidien. Pour la mémoire, le plus efficace reste de quitter les apps gourmandes (Moniteur d'activité).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
            .padding(24)
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private func refresh() {
        disk = SystemStats.disk()
        memory = SystemStats.memory()
        load = SystemStats.loadAverage()
    }
}
