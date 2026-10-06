// swift-tools-version:5.9
import PackageDescription

// Builds the Foundation-only game engine (symlinked from the app) on Linux, without touching the Xcode project:
// - `PacingSim` simulates thousands of careers to measure story pacing (swift run -c release PacingSim).
// - `GosloRecordsTests` runs the app's XCTest suite against the engine (./run-tests.sh).
let package = Package(
    name: "PacingSim",
    targets: [
        .executableTarget(name: "PacingSim", path: "Sources/PacingSim"),
        .target(name: "GosloRecords", path: "Sources/GosloRecords"),
        .testTarget(name: "GosloRecordsTests", dependencies: ["GosloRecords"], path: "Tests/GosloRecordsTests"),
    ]
)
