// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismHarbour",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "PrismCore", targets: ["PrismCore"])],
    targets: [
        .target(name: "PrismCore"),
        .testTarget(name: "PrismCoreTests", dependencies: ["PrismCore"])
    ]
)
