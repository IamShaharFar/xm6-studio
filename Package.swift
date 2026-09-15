// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XM6Companion",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "XM6Companion", targets: ["XM6Companion"])],
    targets: [
        .target(name: "XM6Core", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "XM6Companion", dependencies: ["XM6Core"],
            resources: [.process("Assets")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("IOBluetooth"), .linkedFramework("CoreAudio")]),
        .testTarget(name: "XM6CoreTests", dependencies: ["XM6Core"], swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
