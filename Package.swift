// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Jotwisp",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Jotwisp", targets: ["TextDump"]),
               .library(name: "TextDumpCore", targets: ["TextDumpCore"])],
    targets: [
        .target(name: "TextDumpCore"),
        .executableTarget(name: "TextDump", dependencies: ["TextDumpCore"]),
        .testTarget(name: "TextDumpCoreTests", dependencies: ["TextDumpCore"]),
        .testTarget(name: "TextDumpTests", dependencies: ["TextDump", "TextDumpCore"])
    ]
)
