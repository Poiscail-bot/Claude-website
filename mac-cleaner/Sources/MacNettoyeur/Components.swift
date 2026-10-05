import AppKit
import MacNettoyeurCore
import SwiftUI

enum CheckState {
    case on, off, mixed

    var symbol: String {
        switch self {
        case .on: return "checkmark.square.fill"
        case .off: return "square"
        case .mixed: return "minus.square.fill"
        }
    }
}

struct CheckboxButton: View {
    let state: CheckState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: state.symbol)
                .font(.title3)
                .foregroundStyle(state == .off ? Color.secondary : Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.largeTitle.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

extension View {
    func card(alignment: Alignment = .leading) -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
    }
}

struct RingCard: View {
    let title: String
    let fraction: Double
    let primary: String
    let secondary: String
    let tint: Color

    var body: some View {
        let clamped = max(0, min(fraction, 1))
        VStack(spacing: 12) {
            Text(title).font(.headline)
            ZStack {
                Circle().stroke(tint.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((clamped * 100).rounded())) %")
                    .font(.title2.bold())
                    .monospacedDigit()
            }
            .frame(width: 110, height: 110)
            .animation(.easeOut(duration: 0.6), value: clamped)
            VStack(spacing: 2) {
                Text(primary).font(.callout.weight(.medium))
                Text(secondary).font(.caption).foregroundStyle(.secondary)
            }
        }
        .card(alignment: .center)
    }
}

struct FullDiskAccessBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Accès complet au disque requis").font(.headline)
                Text("macOS protège certains dossiers (Corbeille, pièces jointes Mail, sauvegardes iPhone). Ajoutez MacNettoyeur dans Réglages Système › Confidentialité et sécurité › Accès complet au disque, puis relancez l'app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Ouvrir les réglages") { SystemActions.openFullDiskAccessSettings() }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ReportBanner: View {
    let report: CleanReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(report.failures.isEmpty ? Color.green : Color.orange)
                Text(report.summary).font(.callout.weight(.medium))
            }
            if !report.failures.isEmpty {
                DisclosureGroup("Voir les échecs") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.failures.prefix(30), id: \.url) { failure in
                            Text("\(failure.url.lastPathComponent) — \(failure.reason)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct Badge: View {
    let text: String
    var tint: Color = .orange

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

enum SystemActions {
    static func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    static func openLoginItemsSettings() {
        open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    }

    static func openSecuritySettings() {
        open("x-apple.systempreferences:com.apple.preference.security")
    }

    static func reveal(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + String(path.dropFirst(home.count)) : path
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }
}
