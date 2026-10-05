import Foundation
import XCTest
@testable import MacNettoyeurCore

final class ByteFormatterTests: XCTestCase {
    func testFormatsLikeFinder() {
        XCTAssertEqual(ByteFormatter.string(999), "999 o")
        XCTAssertEqual(ByteFormatter.string(1_500), "1,5 Ko")
        XCTAssertEqual(ByteFormatter.string(150_000_000), "150 Mo")
        XCTAssertEqual(ByteFormatter.string(2_500_000_000), "2,5 Go")
    }
}

final class FileSystemTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("macnettoyeur-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func makeFile(_ relativePath: String, bytes: Int = 20_000) throws -> URL {
        let url = home.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
        return url
    }

    func testSafetyGuard() throws {
        XCTAssertTrue(SafetyGuard.canDelete(home.appendingPathComponent("Library/Caches/com.example"), home: home))
        XCTAssertTrue(SafetyGuard.canDelete(home.appendingPathComponent("Downloads/setup.dmg"), home: home))
        XCTAssertFalse(SafetyGuard.canDelete(home, home: home))
        XCTAssertFalse(SafetyGuard.canDelete(home.appendingPathComponent("Library/Caches"), home: home))
        XCTAssertFalse(SafetyGuard.canDelete(home.appendingPathComponent("Documents"), home: home))
        XCTAssertFalse(SafetyGuard.canDelete(home.appendingPathComponent("Library/Caches/../../Documents"), home: home))
        XCTAssertFalse(SafetyGuard.canDelete(home.appendingPathComponent("Library/Keychains/login.keychain-db"), home: home))
        XCTAssertFalse(SafetyGuard.canDelete(URL(fileURLWithPath: "/etc/hosts"), home: home))
        XCTAssertTrue(SafetyGuard.canDelete(URL(fileURLWithPath: "/Applications/Example.app"), home: home))
        XCTAssertFalse(SafetyGuard.canDelete(URL(fileURLWithPath: "/Applications/Utilities/Example.app"), home: home))
    }

    func testJunkScannerRespectsExclusionsAndExtensions() throws {
        _ = try makeFile("Library/Caches/com.example.app/cache.db")
        _ = try makeFile("Library/Caches/CloudKit/state.db")
        _ = try makeFile("Downloads/installer.dmg")
        _ = try makeFile("Downloads/contrat.pdf")

        let categories = JunkCategory.standard(home: home)
        let caches = JunkScanner().scan(categories.first { $0.id == "user-caches" }!)
        XCTAssertEqual(caches.items.map(\.name), ["com.example.app"])
        XCTAssertGreaterThan(caches.totalSize, 0)

        let installers = JunkScanner().scan(categories.first { $0.id == "installers" }!)
        XCTAssertEqual(installers.items.map(\.name), ["installer.dmg"])

        let missing = JunkScanner().scan(categories.first { $0.id == "logs" }!)
        XCTAssertTrue(missing.items.isEmpty)
        XCTAssertFalse(missing.accessDenied)
    }

    func testCleanerRemovesInsideHomeAndRefusesProtectedPaths() throws {
        let cache = try makeFile("Library/Caches/com.example.app/cache.db")
        let cacheFolder = cache.deletingLastPathComponent()
        let documents = home.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)

        let report = Cleaner(home: home).remove(
            [FileEntry(url: cacheFolder, size: 10), FileEntry(url: documents, size: 5)],
            mode: .permanent
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFolder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: documents.path))
        XCTAssertEqual(report.removedCount, 1)
        XCTAssertEqual(report.freedBytes, 10)
        XCTAssertEqual(report.failures.map(\.url), [documents])
    }

    func testLargeFileScannerSkipsLibrary() throws {
        _ = try makeFile("Movies/film.mov", bytes: 300_000)
        _ = try makeFile("Library/Caches/huge.bin", bytes: 300_000)
        _ = try makeFile("Documents/small.txt", bytes: 1_000)

        let found = LargeFileScanner().scan(home: home, minimumSize: 200_000)
        XCTAssertEqual(found.map(\.url.lastPathComponent), ["film.mov"])
    }

    func testLeftoversMatchBundleIdentifier() throws {
        _ = try makeFile("Library/Preferences/com.example.editor.plist", bytes: 100)
        _ = try makeFile("Library/Application Support/Editor/data.db")
        _ = try makeFile("Library/Group Containers/ABCDE12345.com.example.editor/x")
        _ = try makeFile("Library/Caches/com.example.editorial/x")

        let app = InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Editor.app"),
            name: "Editor", bundleID: "com.example.editor", version: "1.0"
        )
        let names = Set(AppInventory.leftovers(for: app, home: home).map(\.name))
        XCTAssertEqual(names, ["com.example.editor.plist", "Editor", "ABCDE12345.com.example.editor"])
    }
}

final class LaunchItemTests: XCTestCase {
    func testWarnings() {
        let url = URL(fileURLWithPath: "/tmp/test.plist")
        let missing = LaunchItem(
            url: url, plist: ["Label": "a", "Program": "/Applications/Gone.app/Contents/MacOS/helper"],
            scope: .userAgent, fileExists: { _ in false }
        )
        XCTAssertEqual(missing.warnings, ["Programme introuvable (reste d'une app désinstallée ?)"])

        let hidden = LaunchItem(
            url: url, plist: ["Label": "b", "ProgramArguments": ["/Users/me/.local/agent", "--run"], "RunAtLoad": true],
            scope: .userAgent, fileExists: { _ in true }
        )
        XCTAssertEqual(hidden.warnings, ["Emplacement inhabituel"])
        XCTAssertTrue(hidden.runAtLoad)

        let script = LaunchItem(
            url: url, plist: ["ProgramArguments": ["/bin/bash", "-c", "curl …"]],
            scope: .userAgent, fileExists: { _ in true }
        )
        XCTAssertEqual(script.label, "test")
        XCTAssertEqual(script.warnings, ["Lance un script"])
    }
}

final class SecurityAuditorTests: XCTestCase {
    func testParsesSystemToolOutput() {
        XCTAssertEqual(SecurityAuditor.isEnabled("System Integrity Protection status: enabled."), true)
        XCTAssertEqual(SecurityAuditor.isEnabled("assessments disabled"), false)
        XCTAssertEqual(SecurityAuditor.isEnabled("FileVault is On."), true)
        XCTAssertEqual(SecurityAuditor.isEnabled("FileVault is Off."), false)
        XCTAssertEqual(SecurityAuditor.isEnabled("Firewall is disabled. (State = 0)"), false)
        XCTAssertEqual(SecurityAuditor.isEnabled("Firewall is enabled. (State = 1)"), true)
        XCTAssertNil(SecurityAuditor.isEnabled("???"))
    }
}
