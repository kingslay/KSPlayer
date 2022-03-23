// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "KSPlayer",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_13), .iOS(.v11), .tvOS(.v11)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            targets: ["KSPlayer", "FFmpeg"]
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
            dependencies: ["FFmpeg"],
            resources: [.process("Core/Resources"), .process("Metal/Shaders.metal")],
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Security"),
                .linkedFramework("VideoToolbox"),
            ]
        ),
        .target(
            name: "FFmpeg",
            dependencies: ["Libavcodec", "Libavfilter", "Libavformat", "Libavutil", "Libswresample", "Libswscale", "Libssl", "Libcrypto"],
//            dependencies: ["Libssl", "Libcrypto"],
//            exclude: ["include", "compat"],
//            cSettings: [
//                .headerSearchPath("compat"),
//                .headerSearchPath("compat/cuda"),
//                .headerSearchPath("include/libavcodec"),
//                .headerSearchPath("include/libavcodec/aarch64"),
//                .headerSearchPath("include/libavcodec/arm"),
//                .headerSearchPath("include/libavcodec/x86"),
//                .headerSearchPath("include/libavdevice"),
//                .headerSearchPath("include/libavfilter"),
//                .headerSearchPath("include/libavformat"),
//                .headerSearchPath("include/libavutil"),
//                .headerSearchPath("include/libswresample"),
//                .headerSearchPath("include/libswscale"),
//            ],
            linkerSettings: [
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv"),
                .linkedLibrary("xml2"),
                .linkedLibrary("z"),
            ]
        ),
        .executableTarget(
            name: "BuildFFmpeg",
            dependencies: []
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
            name: "Libavfilter",
            path: "Sources/Libavfilter.xcframework"
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
        ),
    ]
)
