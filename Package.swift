// swift-tools-version:5.9
import Foundation
import PackageDescription

let package = Package(
    name: "KSPlayer",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .macCatalyst(.v13), .iOS(.v13), .tvOS(.v13),
                .visionOS(.v1)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            // todo clang: warning: using sysroot for 'iPhoneSimulator' but targeting 'MacOSX' [-Wincompatible-sysroot]
//            type: .dynamic,
            targets: ["KSPlayer"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "KSPlayer",
            dependencies: [
                .product(name: "FFmpegKit", package: "FFmpegKit"),
//                .product(name: "Libass", package: "FFmpegKit"),
//                .product(name: "Libmpv", package: "FFmpegKit"),
                "DisplayCriteria",
            ],
            resources: [.process("Metal/Shaders.metal")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "DisplayCriteria"
        ),
        .testTarget(
            name: "KSPlayerTests",
            dependencies: ["KSPlayer"],
            resources: [.process("Resources")]
        ),
    ]
)

var ffmpegKitPath = FileManager.default.currentDirectoryPath + "/FFmpegKit"
if !FileManager.default.fileExists(atPath: ffmpegKitPath) {
    ffmpegKitPath = FileManager.default.currentDirectoryPath + "../FFmpegKit"
}

if !FileManager.default.fileExists(atPath: ffmpegKitPath) {
    ffmpegKitPath = FileManager.default.currentDirectoryPath + "/KSPlayer/FFmpegKit"
}

if !FileManager.default.fileExists(atPath: ffmpegKitPath), let url = URL(string: #file) {
    let path = url.deletingLastPathComponent().path
    // 解决用xcode引入spm的时候，依赖关系出错的问题
    if !path.contains("/checkouts/") {
        ffmpegKitPath = path + "/FFmpegKit"
    }
}

if FileManager.default.fileExists(atPath: ffmpegKitPath + "/Package.swift") {
    package.dependencies += [
        .package(path: ffmpegKitPath),
    ]
} else {
    package.dependencies += [
        .package(url: "https://github.com/kingslay/FFmpegKit.git", from: "6.1.2"),
    ]
}
