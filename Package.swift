// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KSPlayer",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_13), .iOS(.v10), .tvOS("10.2")],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            targets: ["KSPlayer"]
        ),
        .library(
            name: "Script",
            targets: ["Script"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "KSPlayer",
            dependencies: ["FFmpeg", "Libcrypto", "Libssl"]
        ),
        .target(
            name: "FFmpeg",
            dependencies: ["Libavcodec", "Libavformat", "Libavutil", "Libswresample", "Libswscale"],
            linkerSettings: [.linkedLibrary("bz2"), .linkedLibrary("iconv"), .linkedLibrary("xml2"), .linkedLibrary("z")]
        ),
        .target(
            name: "Script",
            dependencies: [],
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "KSPlayerTests",
            dependencies: ["KSPlayer"],
            resources: [.process("Resources")]
        ),
        .binaryTarget(
            name: "Libavcodec",
            path: "Sources/Libavcodec.xcframework"
        ),
        .binaryTarget(
            name: "Libavformat",
            path: "Sources/Libavformat.xcframework"
        ),
        .binaryTarget(
            name: "Libavutil",
            path: "Sources/Libavutil.xcframework"
        ),
          .binaryTarget(
            name: "Libswresample",
            path: "Sources/Libswresample.xcframework"
        ),
        .binaryTarget(
            name: "Libswscale",
            path: "Sources/Libswscale.xcframework"
        ),
        .binaryTarget(
            name: "Libssl",
            path: "Sources/Libssl.xcframework"
        ),
        .binaryTarget(
            name: "Libcrypto",
            path: "Sources/Libcrypto.xcframework"
        )
    ]
)
