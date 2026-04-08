// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TKRMCPServer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .executableTarget(
            name: "TKRMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            path: "Sources/TKRMCPServer",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "TKRMCPServerTests",
            dependencies: [
                "TKRMCPServer",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests/TKRMCPServerTests"
        ),
        .testTarget(
            name: "TKRMCPServerE2ETests",
            dependencies: [
                "TKRMCPServer",
            ],
            path: "Tests/TKRMCPServerE2ETests"
        ),
    ]
)
