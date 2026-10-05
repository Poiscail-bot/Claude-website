import Foundation

public struct SecurityCheck: Identifiable, Sendable {
    public enum Status: Sendable {
        case ok, warning, unknown
    }

    public let id: String
    public let title: String
    public let detail: String
    public let status: Status
    public let advice: String?
}

public struct AppSignatureResult: Identifiable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let accepted: Bool
    public let source: String
}

/// Vérifie les protections intégrées à macOS. Ce n'est pas un antivirus : la détection
/// de logiciels malveillants connus est assurée par XProtect, intégré au système.
public enum SecurityAuditor {
    /// Interprète la sortie de csrutil, spctl, fdesetup ou socketfilterfw.
    public static func isEnabled(_ output: String) -> Bool? {
        let text = output.lowercased()
        if text.contains("state = 0") { return false }
        if text.contains("state = 1") || text.contains("state = 2") { return true }
        if text.contains("disabled") || text.contains("is off") { return false }
        if text.contains("enabled") || text.contains("is on") { return true }
        return nil
    }

    public static func runChecks() -> [SecurityCheck] {
        var checks = [
            check(
                id: "sip", title: "Protection de l'intégrité du système (SIP)",
                command: "/usr/bin/csrutil", ["status"],
                advice: "Réactivez SIP depuis le mode de récupération avec « csrutil enable »."
            ),
            check(
                id: "gatekeeper", title: "Gatekeeper",
                command: "/usr/sbin/spctl", ["--status"],
                advice: "Réactivez-le dans Réglages Système › Confidentialité et sécurité."
            ),
            check(
                id: "filevault", title: "FileVault (chiffrement du disque)",
                command: "/usr/bin/fdesetup", ["status"],
                advice: "Activez-le dans Réglages Système › Confidentialité et sécurité › FileVault."
            ),
            check(
                id: "firewall", title: "Coupe-feu",
                command: "/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"],
                advice: "Activez-le dans Réglages Système › Réseau › Coupe-feu."
            ),
        ]
        if let version = xprotectVersion() {
            checks.append(SecurityCheck(
                id: "xprotect", title: "XProtect (antivirus intégré)",
                detail: "Définitions version \(version), mises à jour automatiquement par Apple.",
                status: .ok, advice: nil
            ))
        }
        return checks
    }

    static func check(id: String, title: String, command: String, _ arguments: [String], advice: String) -> SecurityCheck {
        let result = Shell.run(command, arguments)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        switch isEnabled(output) {
        case true?:
            return SecurityCheck(id: id, title: title, detail: "Activé", status: .ok, advice: nil)
        case false?:
            return SecurityCheck(id: id, title: title, detail: "Désactivé", status: .warning, advice: advice)
        case nil:
            return SecurityCheck(id: id, title: title, detail: output.isEmpty ? "État inconnu" : output, status: .unknown, advice: nil)
        }
    }

    static func xprotectVersion() -> String? {
        let candidates = [
            "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist",
            "/Library/Apple/System/Library/CoreServices/XProtect.app/Contents/Info.plist",
        ]
        for path in candidates {
            if let version = Plist.dictionary(at: URL(fileURLWithPath: path))["CFBundleShortVersionString"] as? String {
                return version
            }
        }
        return nil
    }

    /// Demande à Gatekeeper si l'app est signée et notarisée.
    public static func assessApp(_ app: InstalledApp) -> AppSignatureResult {
        let result = Shell.run("/usr/sbin/spctl", ["--assess", "--type", "execute", "-vv", app.url.path])
        let sourceLine = result.output
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("source=") })
        let source = sourceLine.map { String($0.dropFirst("source=".count)) } ?? ""
        return AppSignatureResult(url: app.url, name: app.name, accepted: result.status == 0, source: source)
    }
}
