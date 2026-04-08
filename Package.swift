// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TKRMCPServer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "TKRMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TKRMCPServer"
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
