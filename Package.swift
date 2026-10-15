// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MarkdownViewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MarkdownViewer", targets: ["MarkdownViewer"]),
        .library(name: "MarkdownViewerKit", targets: ["MarkdownViewerKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "MarkdownViewerKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .executableTarget(
            name: "MarkdownViewer",
            dependencies: ["MarkdownViewerKit"]
        ),
        .testTarget(
            name: "MarkdownViewerKitTests",
            dependencies: ["MarkdownViewerKit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
