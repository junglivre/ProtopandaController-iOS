// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ProtopandaControllerCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "ProtopandaControllerCore", targets: ["ProtopandaControllerCore"])
    ],
    targets: [
        .target(name: "ProtopandaControllerCore"),
        .testTarget(
            name: "ProtopandaControllerCoreTests",
            dependencies: ["ProtopandaControllerCore"]
        )
    ]
)
