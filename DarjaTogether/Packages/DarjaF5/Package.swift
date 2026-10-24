// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DarjaF5",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DarjaF5", targets: ["DarjaF5"]), .executable(name: "DarjaF5Smoke", targets: ["DarjaF5Smoke"])],
    dependencies: [.package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.21.2")],
    targets: [
        .target(name: "DarjaF5", dependencies: [
            .product(name: "MLX", package: "mlx-swift"), .product(name: "MLXNN", package: "mlx-swift"),
            .product(name: "MLXFast", package: "mlx-swift"), .product(name: "MLXFFT", package: "mlx-swift"),
            .product(name: "MLXLinalg", package: "mlx-swift"), .product(name: "MLXRandom", package: "mlx-swift")
        ]),
        .executableTarget(name: "DarjaF5Smoke", dependencies: ["DarjaF5", .product(name: "MLX", package: "mlx-swift")])
    ]
)
