import MacNettoyeurCore
import SwiftUI

@MainActor
@Observable
final class SecurityModel {
    private(set) var checks: [SecurityCheck] = []
    private(set) var isChecking = false
    private(set) var appResults: [AppSignatureResult] = []
    private(set) var isScanningApps = false
    private(set) var appProgress: Double = 0
    private(set) var hasScannedApps = false

    var rejectedApps: [AppSignatureResult] { appResults.filter { !$0.accepted } }

    var appSummary: String {
        let rejected = rejectedApps.count
        if rejected == 0 {
            return "Toutes les apps (\(appResults.count)) sont signées et approuvées."
        }
        return "\(rejected) app(s) non approuvée(s) sur \(appResults.count)."
    }

    func runChecks() async {
        guard !isChecking else { return }
        isChecking = true
        checks = await Task.detached(priority: .userInitiated) {
            SecurityAuditor.runChecks()
        }.value
        isChecking = false
    }

    func scanApps() async {
        guard !isScanningApps else { return }
        isScanningApps = true
        appResults = []
        appProgress = 0
        let apps = await Task.detached(priority: .userInitiated) {
            AppInventory.installedApps(directories: AppInventory.defaultDirectories())
        }.value
        for (index, app) in apps.enumerated() {
            let result = await Task.detached(priority: .userInitiated) {
                SecurityAuditor.assessApp(app)
            }.value
            appResults.append(result)
            appProgress = Double(index + 1) / Double(max(apps.count, 1))
        }
        appResults.sort { lhs, rhs in
            if lhs.accepted != rhs.accepted { return !lhs.accepted }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        hasScannedApps = true
        isScanningApps = false
    }
}

struct SecurityView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let model = state.security
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Sécurité",
                    subtitle: "Vérification des protections intégrées à macOS",
                    symbol: "checkmark.shield"
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Protections du système").font(.title3.bold())
                        Spacer()
                        if model.isChecking { ProgressView().controlSize(.small) }
                        Button("Vérifier") { Task { await model.runChecks() } }
                            .disabled(model.isChecking)
                    }
                    ForEach(model.checks) { check in
                        HStack(alignment: .top, spacing: 12) {
                            statusIcon(check.status)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.title).font(.body.weight(.medium))
                                Text(check.detail).font(.callout).foregroundStyle(.secondary)
                                if let advice = check.advice {
                                    Text(advice).font(.caption).foregroundStyle(Color.orange)
                                }
                            }
                            Spacer()
                        }
                        Divider()
                    }
                    Button("Ouvrir Confidentialité et sécurité…") { SystemActions.openSecuritySettings() }
                        .buttonStyle(.link)
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Signature des applications").font(.title3.bold())
                        Spacer()
                        Button(model.hasScannedApps ? "Analyser à nouveau" : "Analyser les apps") {
                            Task { await model.scanApps() }
                        }
                        .disabled(model.isScanningApps)
                    }
                    Text("Gatekeeper vérifie que chaque app est signée par un développeur identifié et notarisée par Apple. Une app refusée n'est pas forcément malveillante (logiciel libre, outil compilé localement), mais vérifiez qu'elle vient d'une source fiable.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.isScanningApps {
                        ProgressView(value: model.appProgress)
                    }
                    if model.hasScannedApps {
                        Text(model.appSummary)
                            .font(.callout.weight(.medium))
                    }
                    ForEach(model.appResults) { result in
                        HStack(spacing: 10) {
                            Image(nsImage: SystemActions.icon(for: result.url))
                                .resizable()
                                .frame(width: 22, height: 22)
                            Text(result.name)
                            Spacer()
                            if result.accepted {
                                Text(result.source.isEmpty ? "Approuvée" : result.source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.green)
                            } else {
                                Badge(text: "Non approuvée par Gatekeeper")
                            }
                        }
                        .contextMenu {
                            Button("Afficher dans le Finder") { SystemActions.reveal([result.url]) }
                        }
                    }
                }
                .card()

                Label("MacNettoyeur n'est pas un antivirus. macOS intègre XProtect, mis à jour automatiquement par Apple, qui bloque et supprime les logiciels malveillants connus. Gardez macOS à jour : c'est la protection la plus efficace.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .task {
            if model.checks.isEmpty { await model.runChecks() }
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: SecurityCheck.Status) -> some View {
        switch status {
        case .ok:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green).font(.title3)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange).font(.title3)
        case .unknown:
            Image(systemName: "questionmark.circle").foregroundStyle(Color.secondary).font(.title3)
        }
    }
}
