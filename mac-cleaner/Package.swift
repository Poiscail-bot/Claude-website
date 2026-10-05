// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MacNettoyeur",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacNettoyeur", targets: ["MacNettoyeur"]),
    ],
    targets: [
        .target(name: "MacNettoyeurCore"),
        .executableTarget(name: "MacNettoyeur", dependencies: ["MacNettoyeurCore"]),
        .testTarget(name: "MacNettoyeurCoreTests", dependencies: ["MacNettoyeurCore"]),
    ]
)
