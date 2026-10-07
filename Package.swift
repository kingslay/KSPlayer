// swift-tools-version:6.2
import Foundation
import PackageDescription

let package = Package(
    name: "KSPlayer",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13), .macCatalyst(.v14), .macOS(.v10_15), .tvOS(.v13), .visionOS(.v1),
//        .watchOS(.v9),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KSPlayer",
            targets: ["KSPlayer"]
        ),
        .library(
            name: "KSPlayerUI",
            // todo clang: warning: using sysroot for 'iPhoneSimulator' but targeting 'MacOSX' [-Wincompatible-sysroot]
            type: ProcessInfo.processInfo.environment["dynamicFrameWork"] == nil ? .static : .dynamic,
            targets: ["KSPlayerUI"]
        ),
        .library(
            name: "MPVPlayer",
            type: ProcessInfo.processInfo.environment["dynamicFrameWork"] == nil ? .static : .dynamic,
            targets: ["MPVPlayer"]
        ),
    ],
    targets: [
        .target(
            name: "MPVPlayer",
            dependencies: [
                "KSPlayer",
                .product(name: "libmpv", package: "FFmpegKit"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-experimental-package-interface-load",
                ]),
            ]
        ),
        .binaryTarget(
            name: "KSPlayer",
            path: "Sources/KSPlayer.xcframework"
        ),
        .target(
            name: "KSPlayerUI",
            dependencies: [
                "KSPlayer",
            ],
            resources: [
                .process("Localizable.xcstrings"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-experimental-package-interface-load",
                ]),
            ]
        ),
        .target(
            name: "DisplayCriteria",
            dependencies: [
                "FFmpegKit",
            ]
        ),
        .testTarget(
            name: "KSPlayerUITests",
            dependencies: ["KSPlayerUI"]
        ),
    ],
    swiftLanguageModes: [
        .v5,
        .v6,
    ]
)

var ffmpegKitPath = FileManager.default.currentDirectoryPath + "/../FFmpegKit"
// spm FileManager.default.currentDirectoryPath返回的空字符，spm6.0#file返回的不是当前的目录。要改成用#filePath
if !FileManager.default.fileExists(atPath: ffmpegKitPath), let url = URL(string: #filePath) {
    let path = url.deletingLastPathComponent().path
    // 解决用xcode引入spm的时候，依赖关系出错的问题
    if !path.contains("/checkouts/") {
        ffmpegKitPath = path + "/../FFmpegKit"
    }
}

if FileManager.default.fileExists(atPath: ffmpegKitPath + "/Package.swift") {
    package.dependencies += [
        .package(path: ffmpegKitPath),
    ]
} else {
    package.dependencies += [
        .package(url: "https://github.com/kingslay/FFmpegKit.git", from: "9.0.2"),
    ]
}
