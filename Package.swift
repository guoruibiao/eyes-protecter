// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyesProtecter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EyesProtecter", targets: ["EyesProtecter"])
    ],
    targets: [
        .executableTarget(
            name: "EyesProtecter",
            path: "Sources/EyesProtecter"
        )
    ]
)
