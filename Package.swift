// swift-tools-version:5.7
import Foundation
import PackageDescription
let package = Package(
    name: "KSPlayer",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            type: .static,
            targets: ["KSPlayer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kingslay/FFmpegKit.git", from: "5.1.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "KSPlayer",
            dependencies: [.product(name: "FFmpeg", package: "FFmpegKit")],
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
        .testTarget(
            name: "KSPlayerTests",
            dependencies: ["KSPlayer"],
            resources: [.process("Resources")]
        ),
    ]
)
var ffmpegKitPath = FileManager.default.currentDirectoryPath + "/../FFmpegKit"
ffmpegKitPath = "../FFmpegKit"
// if !FileManager.default.fileExists(atPath: ffmpegKitPath) {
//     ffmpegKitPath = (ProcessInfo.processInfo.environment["OLDPWD"] ?? "") + "/../FFmpegKit"
// }

if !FileManager.default.fileExists(atPath: ffmpegKitPath) {
    ffmpegKitPath = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/Github/FFmpegKit"
}

if FileManager.default.fileExists(atPath: ffmpegKitPath) {
    package.dependencies = [
        .package(path: ffmpegKitPath),
    ]
}
