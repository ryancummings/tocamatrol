// swift-tools-version: 6.0
// Hardware-free Tocamatrol logic: packet encoding, pointer and scroll curves, send
// accumulation and trackpad gestures. Foundation only, so `swift test` runs on a Mac
// or on Linux.
import PackageDescription

let package = Package(
    name: "TocaCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TocaCore", targets: ["TocaCore"])],
    targets: [
        .target(name: "TocaCore"),
        .testTarget(name: "TocaCoreTests", dependencies: ["TocaCore"]),
    ]
)
