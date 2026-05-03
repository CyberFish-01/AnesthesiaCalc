// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AnesthesiaCalcCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AnesthesiaCalcCore",
            targets: ["AnesthesiaCalcCore"]
        )
    ],
    targets: [
        .target(
            name: "AnesthesiaCalcCore",
            path: "Sources/AnesthesiaCalcCore"
        ),
        .testTarget(
            name: "AnesthesiaCalcCoreTests",
            dependencies: ["AnesthesiaCalcCore"],
            path: "Tests/AnesthesiaCalcCoreTests"
        )
    ]
)
