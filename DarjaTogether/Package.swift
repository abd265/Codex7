// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DarjaTogether",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DarjaCore", targets: ["DarjaCore"])],
    targets: [
        .target(name: "DarjaCore"),
        .testTarget(name: "DarjaCoreTests", dependencies: ["DarjaCore"])
    ]
)
