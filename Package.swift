// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "RiseBakeCore", products: [.library(name: "RiseBakeCore", targets: ["RiseBakeCore"])], targets: [.target(name: "RiseBakeCore"), .testTarget(name: "RiseBakeCoreTests", dependencies: ["RiseBakeCore"], resources: [.copy("seed.json")])])
