// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Trast",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Trast", targets: ["Trast"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0")
    ],
    targets: [
        .target(
            name: "TrastCore",
            path: "Sources/TrastCore"
        ),
        .executableTarget(
            name: "Trast",
            dependencies: [
                "TrastCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/Trast"
        ),
        .executableTarget(
            name: "TrastTests",
            dependencies: ["TrastCore"],
            path: "Tests/TrastTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
