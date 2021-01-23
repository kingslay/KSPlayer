// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KSPlayer",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_12), .iOS(.v10), .tvOS("10.2")],
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
            dependencies: ["FFmpeg", "libcrypto", "libssl"]
        ),
        .target(
            name: "FFmpeg",
            dependencies: ["libavcodec", "libavformat", "libavutil", "libswresample", "libswscale"],
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
            name: "libavcodec",
            path: "Sources/libavcodec.xcframework"
        ),
        .binaryTarget(
            name: "libavformat",
            path: "Sources/libavformat.xcframework"
        ),
        .binaryTarget(
            name: "libavutil",
            path: "Sources/libavutil.xcframework"
        ),
          .binaryTarget(
            name: "libswresample",
            path: "Sources/libswresample.xcframework"
        ),
        .binaryTarget(
            name: "libswscale",
            path: "Sources/libswscale.xcframework"
        ),
        .binaryTarget(
            name: "libssl",
            path: "Sources/libssl.xcframework"
        ),
        .binaryTarget(
            name: "libcrypto",
            path: "Sources/libcrypto.xcframework"
        )
    ]
)
