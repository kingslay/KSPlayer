// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KSPlayer",
    platforms: [.macOS(.v10_11), .iOS(.v9), .tvOS("10.2")],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            targets: ["KSPlayer"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "KSPlayer",
            path: "Sources",
            cSettings: [
                .headerSearchPath("FFmpeg/FFmpeg.xcframework/ios-arm64/Headers"),
            ],
            swiftSettings: [
                .unsafeFlags(["-F FFmpeg"]),
            ],
            linkerSettings: [
                .linkedFramework("FFmpeg"),
            ]
        ),
        .testTarget(
            name: "KSPlayerTests",
            dependencies: ["KSPlayer"],
            path: "Tests"
        ),
        // .target(
        //     name: "UXKit",
        //     dependencies: [],
        //     exclude: excludes
        // ),
        // .target(
        //     name: "Basic",
        //     dependencies: ["UXKit"]
        // ),
        // .target(
        //     name: "SubtitleCore",
        //     dependencies: []
        // ),
        // .target(
        //     name: "Subtitle",
        //     dependencies: ["SubtitleCore", "Basic", "Resources"],
        //     exclude: excludes
        // ),
        // .target(
        //     name: "Metal",
        //     dependencies: []
        // ),
        // .target(
        //     name: "AVPlayer",
        //     dependencies: ["Basic"]
        // ),
        // .target(
        //     name: "MEPlayer",
        //     dependencies: ["FFmpeg", "AVPlayer", "Metal", "SubtitleCore"]
        // ),
        // .target(
        //     name: "Panorama",
        //     dependencies: ["Basic", "Metal"]
        // ),
        // .target(
        //     name: "VRPlayer",
        //     dependencies: ["MEPlayer", "Panorama"]
        // ),
        // .target(
        //     name: "Resources",
        //     dependencies: []
        // ),
        // .target(
        //     name: "Core",
        //     dependencies: ["AVPlayer", "Resources"]
        // ),
        // .target(
        //     name: "Audio",
        //     dependencies: ["Core", "SubtitleCore"]
        // ),
        // .target(
        //     name: "Video",
        //     dependencies: ["Core", "Subtitle"],
        //     exclude: excludes
        // ),
    ]
)
