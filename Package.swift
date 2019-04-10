// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
#if os(macOS)

let excludes = ["iOS", "Linux"]

#elseif os(iOS)

let excludes = ["Linux", "macOS"]

#elseif os(Linux)

let excludes = ["iOS", "macOS"]

#endif

let package = Package(
    name: "KSPlayer",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            targets: ["Video"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "UXKit",
            dependencies: [],
            exclude: excludes
        ),
        .target(
            name: "Basic",
            dependencies: ["UXKit"]
        ),
        .target(
            name: "SubtitleCore",
            dependencies: []
        ),
        .target(
            name: "Subtitle",
            dependencies: ["SubtitleCore", "Basic", "Resources"],
            exclude: excludes
        ),
        .target(
            name: "FFmpeg",
            dependencies: []
        ),
        .target(
            name: "Metal",
            dependencies: []
        ),
        .target(
            name: "AVPlayer",
            dependencies: ["Basic"]
        ),
        .target(
            name: "MEPlayer",
            dependencies: ["FFmpeg", "AVPlayer", "Metal", "SubtitleCore"]
        ),
        .target(
            name: "Panorama",
            dependencies: ["Basic", "Metal"]
        ),
        .target(
            name: "VRPlayer",
            dependencies: ["MEPlayer", "Panorama"]
        ),
        .target(
            name: "Resources",
            dependencies: []
        ),
        .target(
            name: "Core",
            dependencies: ["AVPlayer", "Resources"]
        ),
        .target(
            name: "Audio",
            dependencies: ["Core", "SubtitleCore"]
        ),
        .target(
            name: "Video",
            dependencies: ["Core", "Subtitle"],
            exclude: excludes
        ),
        .testTarget(
            name: "KSPlayerTests",
            dependencies: ["Video"],
            path: "Tests"
        ),
    ]
)
