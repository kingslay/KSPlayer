import Foundation
// import PackagePlugin
//
// @main struct BuildFFmpeg: CommandPlugin {
@main enum BuildFFmpeg {
    static func main() {
        performCommand(arguments: Array(CommandLine.arguments.dropFirst()))
    }

//    func performCommand(context _: PluginContext, arguments: [String]) throws {
//        performCommand(arguments: arguments)
//    }
    static func performCommand(arguments: [String]) {
        if Utility.shell("which brew") == nil {
            print("""
            You need to run the script first
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            """)
            return
        }

        let path = URL.currentDirectory + "Script"
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: false, attributes: nil)
        }
        FileManager.default.changeCurrentDirectoryPath(path.path)
        BaseBuild.platforms = arguments.compactMap { argument in
            if argument.hasPrefix("platform=") {
                let value = String(argument.suffix(argument.count - "platform=".count))
                return PlatformType(rawValue: value)
            } else {
                return nil
            }
        }
        if BaseBuild.platforms.isEmpty {
            BaseBuild.platforms = PlatformType.allCases
        }

        let enableOpenssl = arguments.firstIndex(of: "enable-openssl") != nil
        if enableOpenssl {
            BuildOpenSSL().buildALL()
            // BuildBoringSSL().buildALL()
        }
        if Utility.shell("which pkg-config") == nil {
            Utility.shell("brew install pkg-config")
        }
        let enableSrt = arguments.firstIndex(of: "enable-libsrt") != nil
        if enableSrt {
            BuildSRT().buildALL()
        }
        BuildFFMPEG(arguments: arguments).buildALL()
    }
}

private class BaseBuild {
    static var platforms = PlatformType.allCases
    private let library: String
    init(library: String) {
        self.library = library
    }

    func buildALL() {
        try? FileManager.default.removeItem(at: URL.currentDirectory + library)
        for platform in BaseBuild.platforms {
            for arch in platform.architectures() {
                build(platform: platform, arch: arch)
            }
        }
        createXCFramework()
    }

    func architectures(_ platform: PlatformType) -> [ArchType] {
        platform.architectures()
    }

    private func build(platform: PlatformType, arch: ArchType) {
        let url = scratch(platform: platform, arch: arch)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        let cflags = "-arch " + arch.rawValue + " -fembed-bitcode " + platform.deploymentTarget(arch)
        innerBuid(platform: platform, arch: arch, cflags: cflags, buildDir: url)
    }

    func innerBuid(platform _: PlatformType, arch _: ArchType, cflags _: String, buildDir _: URL) {}

    func createXCFramework() {
        for framework in frameworks() {
            var arguments = ""
            let XCFrameworkFile = URL.currentDirectory + ["../Sources", framework + ".xcframework"]
            if FileManager.default.fileExists(atPath: XCFrameworkFile.path) {
                try? FileManager.default.removeItem(at: XCFrameworkFile)
            }
            for platform in BaseBuild.platforms {
                arguments += " -framework \(createFramework(framework: framework, platform: platform))"
            }
            Utility.shell("xcodebuild -create-xcframework\(arguments) -output \(XCFrameworkFile.path)")
        }
    }

    private func createFramework(framework: String, platform: PlatformType) -> String {
        let frameworkDir = URL.currentDirectory + [library, platform.rawValue, "\(framework).framework"]
        try? FileManager.default.removeItem(at: frameworkDir)
        try? FileManager.default.createDirectory(at: frameworkDir, withIntermediateDirectories: true, attributes: nil)
        var command = "lipo -create"
        for arch in architectures(platform) {
            let prefix = thinDir(platform: platform, arch: arch)
            command += " "
            command += (prefix + ["lib", "\(framework).a"]).path
            var headerURL = prefix + "include" + framework
            if !FileManager.default.fileExists(atPath: headerURL.path) {
                headerURL = prefix + "include"
            }
            try? FileManager.default.copyItem(at: headerURL, to: frameworkDir + "Headers")
        }
        command += " -output "
        command += (frameworkDir + framework).path
        Utility.shell(command)
        try? FileManager.default.createDirectory(at: frameworkDir + "Modules", withIntermediateDirectories: true, attributes: nil)
        var modulemap = """
        framework module \(framework) [system] {
            umbrella "."

        """
        frameworkExcludeHeaders(framework).forEach { header in
            modulemap += """
                exclude header "\(header).h"

            """
        }
        modulemap += """
            export *
        }
        """
        FileManager.default.createFile(atPath: frameworkDir.path + "/Modules/module.modulemap", contents: modulemap.data(using: .utf8), attributes: nil)
        createPlist(path: frameworkDir.path + "/Info.plist", name: framework, minVersion: platform.minVersion, platform: platform.sdk())
        return frameworkDir.path
    }

    func thinDir(platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library, platform.rawValue, "thin", arch.rawValue]
    }

    func scratch(platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library, platform.rawValue, "scratch", arch.rawValue]
    }

    func frameworks() -> [String] {
        []
    }

    func frameworkExcludeHeaders(_: String) -> [String] {
        []
    }

    func createPlist(path: String, name: String, minVersion: String, platform: String) {
        let identifier = "com.kintan.ksplayer." + name
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>\(name)</string>
        <key>CFBundleIdentifier</key>
        <string>\(identifier)</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>\(name)</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>87.88.520</string>
        <key>CFBundleVersion</key>
        <string>87.88.520</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>MinimumOSVersion</key>
        <string>\(minVersion)</string>
        <key>CFBundleSupportedPlatforms</key>
        <array>
        <string>\(platform)</string>
        </array>
        <key>NSPrincipalClass</key>
        <string></string>
        </dict>
        </plist>
        """
        FileManager.default.createFile(atPath: path, contents: content.data(using: .utf8), attributes: nil)
    }
}

private class BuildFFMPEG: BaseBuild {
    private let ffmpegFile = "ffmpeg-5.1.2"
    private let isDebug: Bool
    init(arguments: [String]) {
        isDebug = arguments.firstIndex(of: "enable-debug") != nil
        super.init(library: "FFmpeg")
    }

    override func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {
        var ffmpegcflags = ffmpegConfiguers
        if isDebug {
            ffmpegcflags.append("--enable-debug")
            ffmpegcflags.append("--disable-stripping")
            ffmpegcflags.append("--disable-optimizations")
        } else {
            ffmpegcflags.append("--disable-debug")
            ffmpegcflags.append("--enable-stripping")
            ffmpegcflags.append("--enable-optimizations")
        }
        /**
         aacpsdsp.o), building for Mac Catalyst, but linking in object file built for
         x86_64 binaries are built without ASM support, since ASM for x86_64 is actually x86 and that confuses `xcodebuild -create-xcframework` https://stackoverflow.com/questions/58796267/building-for-macos-but-linking-in-object-file-built-for-free-standing/59103419#59103419
         */
        if platform == .maccatalyst || arch == .x86_64 {
            ffmpegcflags.append("--disable-neon")
            ffmpegcflags.append("--disable-asm")
        } else {
            ffmpegcflags.append("--enable-neon")
            ffmpegcflags.append("--enable-asm")
        }
        if platform == .macos, arch.executable() {
            ffmpegcflags.append("--enable-ffplay")
            ffmpegcflags.append("--enable-avdevice")
            ffmpegcflags.append("--enable-sdl2")
            ffmpegcflags.append("--enable-encoder=aac")
            ffmpegcflags.append("--enable-encoder=movtext")
            ffmpegcflags.append("--enable-encoder=mpeg4")
            ffmpegcflags.append("--enable-decoder=rawvideo")
            ffmpegcflags.append("--enable-indev=lavfi")
            ffmpegcflags.append("--enable-filter=color")
            ffmpegcflags.append("--enable-filter=lut")
            ffmpegcflags.append("--enable-filter=negate")
            ffmpegcflags.append("--enable-filter=testsrc")
        } else {
            ffmpegcflags.append("--disable-avdevice")
            ffmpegcflags.append("--disable-programs")
        }
//        if platform == .isimulator || platform == .tvsimulator {
//            ffmpegcflags.append("--assert-level=1")
//        }
        var cflags = cflags
        var ldflags = "-arch \(arch.rawValue) "
        if platform == .maccatalyst {
            let syslibroot = platform.isysroot()
            cflags += " -isysroot \(syslibroot) -iframework \(syslibroot)/System/iOSSupport/System/Library/Frameworks"
            ldflags = cflags
        }
        let opensslPath = URL.currentDirectory + ["SSL", platform.rawValue, "thin", arch.rawValue]
        var pkgConfigPath = ""
        if FileManager.default.fileExists(atPath: opensslPath.path) {
            pkgConfigPath += "\(opensslPath.path)/lib/pkgconfig:"
            ffmpegcflags.append("--enable-openssl")
        }
        let srtPath = URL.currentDirectory + ["SRT", platform.rawValue, "thin", arch.rawValue]
        if FileManager.default.fileExists(atPath: srtPath.path) {
            pkgConfigPath += "\(srtPath.path)/lib/pkgconfig:"
            ffmpegcflags.append("--enable-libsrt")
            ffmpegcflags.append("--enable-protocol=libsrt")
        }
        let prefix = thinDir(platform: platform, arch: arch)
        var args = ["set -o noglob &&",
                    (URL.currentDirectory + [ffmpegFile, "configure"]).path,
                    "--target-os=darwin",
                    "--arch=\(arch.arch())",
                    platform.cpu(arch: arch),
                    "--cc='xcrun -sdk \(platform.sdk().lowercased()) clang'",
                    "--extra-cflags='\(cflags)'",
                    "--extra-ldflags='\(ldflags)'",
                    "--prefix=\(prefix.path)"]
        args.append(contentsOf: ffmpegcflags)
        let environment = ["PKG_CONFIG_PATH": pkgConfigPath]
        Utility.shell(args.joined(separator: " "), currentDirectoryURL: buildDir, environment: environment)
        Utility.shell("make -j8 install\(arch == .x86_64 ? "" : " GASPP_FIX_XCODE5=1") >>\(buildDir.path).log", currentDirectoryURL: buildDir)
        let lldbFile = URL.currentDirectory + "LLDBInitFile"
        if let data = FileManager.default.contents(atPath: lldbFile.path), var str = String(data: data, encoding: .utf8) {
            str.append("settings \(str.count == 0 ? "set" : "append") target.source-map \((buildDir + "src").path) \((URL.currentDirectory + ffmpegFile).path)\n")
            try? str.write(toFile: lldbFile.path, atomically: true, encoding: .utf8)
        }
        if platform == .macos, arch.executable() {
            replaceBin(prefix: prefix, item: "ffmpeg")
            replaceBin(prefix: prefix, item: "ffplay")
            replaceBin(prefix: prefix, item: "ffprobe")
        }
    }

    private func replaceBin(prefix: URL, item: String) {
        if FileManager.default.fileExists(atPath: (prefix + ["bin", item]).path) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/\(item)"))
            try? FileManager.default.copyItem(at: prefix + ["bin", item], to: URL(fileURLWithPath: "/usr/local/bin/\(item)"))
        }
    }

    override func frameworks() -> [String] {
        ["Libavcodec", "Libavformat", "Libavutil", "Libswresample", "Libswscale", "Libavfilter"]
    }

    override func createXCFramework() {
        super.createXCFramework()
//        makeFFmpegSourece()
    }

    private func makeFFmpegSourece() {
        guard let platform = BaseBuild.platforms.first, let arch = platform.architectures().first else {
            return
        }
        let target = URL.currentDirectory + ["../Sources", "FFmpeg"]
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true, attributes: nil)
        let thin = thinDir(platform: platform, arch: arch)
        try? FileManager.default.copyItem(at: thin + "include", to: target + "include")
        let scratch = scratch(platform: platform, arch: arch)
        try? FileManager.default.createDirectory(at: target + "include", withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.copyItem(at: scratch + "config.h", to: target + "include" + "config.h")
        guard let fileNames = try? FileManager.default.contentsOfDirectory(atPath: scratch.path) else {
            return
        }
        for fileName in fileNames where fileName.hasPrefix("lib") {
            var url = scratch + fileName
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                // copy .c
                if let subpaths = FileManager.default.enumerator(atPath: url.path) {
                    let dstDir = target + fileName
                    while let subpath = subpaths.nextObject() as? String {
                        if subpath.hasSuffix(".c") {
                            let srcURL = url + subpath
                            let dstURL = target + "include" + fileName + subpath
                            try? FileManager.default.copyItem(at: srcURL, to: dstURL)
                        } else if subpath.hasSuffix(".o") {
                            let subpath = subpath.replacingOccurrences(of: ".o", with: ".c")
                            let srcURL = scratch + "src" + fileName + subpath
                            let dstURL = dstDir + subpath
                            let dstURLDir = dstURL.deletingLastPathComponent()
                            if !FileManager.default.fileExists(atPath: dstURLDir.path) {
                                try? FileManager.default.createDirectory(at: dstURLDir, withIntermediateDirectories: true, attributes: nil)
                            }
                            try? FileManager.default.copyItem(at: srcURL, to: dstURL)
                        }
                    }
                }
                url = scratch + "src" + fileName
                // copy .h
                try? FileManager.default.copyItem(at: scratch + "src" + "compat", to: target + "compat")
                if let subpaths = FileManager.default.enumerator(atPath: url.path) {
                    let dstDir = target + "include" + fileName
                    while let subpath = subpaths.nextObject() as? String {
                        if subpath.hasSuffix(".h") || subpath.hasSuffix("_template.c") {
                            let srcURL = url + subpath
                            let dstURL = dstDir + subpath
                            let dstURLDir = dstURL.deletingLastPathComponent()
                            if !FileManager.default.fileExists(atPath: dstURLDir.path) {
                                try? FileManager.default.createDirectory(at: dstURLDir, withIntermediateDirectories: true, attributes: nil)
                            }
                            try? FileManager.default.copyItem(at: srcURL, to: dstURL)
                        }
                    }
                }
            }
        }
    }

    override func buildALL() {
        prepareAsm()
        if !FileManager.default.fileExists(atPath: (URL.currentDirectory + ffmpegFile).path) {
            Utility.shell("curl http://www.ffmpeg.org/releases/\(ffmpegFile).tar.bz2 | tar xj")
        }
        let lldbFile = URL.currentDirectory + "LLDBInitFile"
        try? FileManager.default.removeItem(at: lldbFile)
        FileManager.default.createFile(atPath: lldbFile.path, contents: nil, attributes: nil)
        let path = URL.currentDirectory + ffmpegFile + "libavcodec/videotoolbox.c"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "kCVPixelBufferOpenGLESCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            str = str.replacingOccurrences(of: "kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            try? str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
        super.buildALL()
    }

    private func prepareAsm() {
        if Utility.shell("which nasm") == nil {
            Utility.shell("brew install nasm")
        }
        if Utility.shell("which sdl2-config") == nil {
            Utility.shell("brew install sdl2")
        }
    }

    override func frameworkExcludeHeaders(_ framework: String) -> [String] {
        if framework == "Libavcodec" {
            return ["xvmc", "vdpau", "qsv", "dxva2", "d3d11va"]
        } else if framework == "Libavutil" {
            return ["hwcontext_vulkan", "hwcontext_vdpau", "hwcontext_vaapi", "hwcontext_qsv", "hwcontext_opencl", "hwcontext_dxva2", "hwcontext_d3d11va", "hwcontext_cuda"]
        } else {
            return super.frameworkExcludeHeaders(framework)
        }
    }

    private let ffmpegConfiguers = [
        // Configuration options:
        "--disable-armv5te", "--disable-armv6", "--disable-armv6t2", "--disable-bsfs",
        "--disable-bzlib", "--disable-gray", "--disable-iconv", "--disable-linux-perf",
        "--disable-xlib", "--disable-shared", "--disable-swscale-alpha", "--disable-symver", "--disable-small",
        "--enable-cross-compile", "--enable-gpl", "--enable-libxml2", "--enable-nonfree",
        "--enable-runtime-cpudetect", "--enable-thumb", "--enable-version3", "--enable-static",
        "--pkg-config-flags=--static",
        // Documentation options:
        "--disable-doc", "--disable-htmlpages", "--disable-manpages", "--disable-podpages", "--disable-txtpages",
        // Component options:
        "--enable-avcodec", "--enable-avformat", "--enable-avutil", "--enable-network", "--enable-swresample", "--enable-swscale",
        "--disable-devices", "--disable-outdevs", "--disable-indevs", "--disable-postproc",
        // ,"--disable-pthreads"
        // ,"--disable-w32threads"
        // ,"--disable-os2threads"
        // ,"--disable-dct"
        // ,"--disable-dwt"
        // ,"--disable-lsp"
        // ,"--disable-lzo"
        // ,"--disable-mdct"
        // ,"--disable-rdft"
        // ,"--disable-fft"
        // Hardware accelerators:
        "--disable-d3d11va", "--disable-dxva2", "--disable-vaapi", "--disable-vdpau",
        "--enable-videotoolbox", "--enable-audiotoolbox",
        // Individual component options:
        // ,"--disable-everything"
        // 用所有的encoders的话，那avcodec就会达到40MB了，指定的话，那就只要20MB。
        "--disable-encoders",
        // ./configure --list-decoders
        "--disable-decoders",
        // 视频
        "--enable-decoder=av1", "--enable-decoder=dca", "--enable-decoder=flv", "--enable-decoder=h263",
        "--enable-decoder=h263i", "--enable-decoder=h263p", "--enable-decoder=h264", "--enable-decoder=hevc",
        "--enable-decoder=mjpeg", "--enable-decoder=mjpegb", "--enable-decoder=mpeg1video", "--enable-decoder=mpeg2video",
        "--enable-decoder=mpeg4", "--enable-decoder=mpegvideo", "--enable-decoder=rv30", "--enable-decoder=rv40",
        "--enable-decoder=tscc", "--enable-decoder=wmv1", "--enable-decoder=wmv2", "--enable-decoder=wmv3",
        "--enable-decoder=vc1", "--enable-decoder=vp6", "--enable-decoder=vp6a", "--enable-decoder=vp6f",
        "--enable-decoder=vp7", "--enable-decoder=vp8", "--enable-decoder=vp9",
        // 音频
        "--enable-decoder=aac*", "--enable-decoder=ac3*", "--enable-decoder=alac*",
        "--enable-decoder=amr*", "--enable-decoder=ape", "--enable-decoder=cook",
        "--enable-decoder=dca", "--enable-decoder=dolby_e", "--enable-decoder=eac3*", "--enable-decoder=flac",
        "--enable-decoder=mp1*", "--enable-decoder=mp2*", "--enable-decoder=mp3*", "--enable-decoder=opus",
        "--enable-decoder=pcm*", "--enable-decoder=truehd", "--enable-decoder=vorbis", "--enable-decoder=wma*",
        // 字幕
        "--enable-decoder=ass", "--enable-decoder=dvbsub", "--enable-decoder=dvdsub", "--enable-decoder=movtext",
        "--enable-decoder=pgssub", "--enable-decoder=srt", "--enable-decoder=ssa", "--enable-decoder=subrip",
        "--enable-decoder=webvtt",
        // ./configure --list-muxers
        "--disable-muxers",
        "--enable-muxer=dash", "--enable-muxer=hevc", "--enable-muxer=mp4", "--enable-muxer=m4v", "--enable-muxer=mov",
        "--enable-muxer=mpegts", "--enable-muxer=webm*",
        // ./configure --list-demuxers
        // 用所有的demuxers的话，那avformat就会达到8MB了，指定的话，那就只要4MB。
        "--disable-demuxers",
        "--enable-demuxer=aac", "--enable-demuxer=ac3", "--enable-demuxer=aiff", "--enable-demuxer=amr",
        "--enable-demuxer=ape", "--enable-demuxer=asf", "--enable-demuxer=ass", "--enable-demuxer=avi", "--enable-demuxer=caf",
        "--enable-demuxer=concat", "--enable-demuxer=dash", "--enable-demuxer=data", "--enable-demuxer=eac3",
        "--enable-demuxer=flac", "--enable-demuxer=flv", "--enable-demuxer=h264", "--enable-demuxer=hevc",
        "--enable-demuxer=hls", "--enable-demuxer=live_flv", "--enable-demuxer=loas", "--enable-demuxer=m4v",
        "--enable-demuxer=matroska", "--enable-demuxer=mov", "--enable-demuxer=mp3", "--enable-demuxer=mpeg*",
        "--enable-demuxer=ogg", "--enable-demuxer=rm", "--enable-demuxer=rtsp", "--enable-demuxer=srt",
        "--enable-demuxer=vc1", "--enable-demuxer=wav", "--enable-demuxer=webm_dash_manifest",
        // ./configure --list-protocols
        "--enable-protocols",
        "--disable-protocol=bluray", "--disable-protocol=ffrtmpcrypt", "--disable-protocol=gopher", "--disable-protocol=icecast",
        "--disable-protocol=librtmp*", "--disable-protocol=libssh", "--disable-protocol=md5", "--disable-protocol=mmsh",
        "--disable-protocol=mmst", "--disable-protocol=sctp", "--disable-protocol=subfile", "--disable-protocol=unix",
        // filters
        "--disable-filters",
        "--enable-filter=aformat", "--enable-filter=amix", "--enable-filter=anull", "--enable-filter=aresample",
        "--enable-filter=areverse", "--enable-filter=asetrate", "--enable-filter=atempo", "--enable-filter=atrim",
        "--enable-filter=bwdif", "--enable-filter=estdif", "--enable-filter=format", "--enable-filter=fps",
        "--enable-filter=hflip", "--enable-filter=hwdownload", "--enable-filter=hwmap", "--enable-filter=hwupload",
        "--enable-filter=idet", "--enable-filter=null",
        "--enable-filter=overlay", "--enable-filter=palettegen", "--enable-filter=paletteuse", "--enable-filter=pan",
        "--enable-filter=rotate", "--enable-filter=scale", "--enable-filter=setpts", "--enable-filter=transpose",
        "--enable-filter=trim", "--enable-filter=vflip", "--enable-filter=volume", "--enable-filter=w3fdif",
        "--enable-filter=yadif", "--enable-filter=yadif_videotoolbox",
    ]
}

private class BuildSRT: BaseBuild {
    private let version = "1.5.0"
    init() {
        super.init(library: "SRT")
    }

    override func buildALL() {
        if Utility.shell("which cmake") == nil {
            Utility.shell("brew install cmake")
        }
        if Utility.shell("which wget") == nil {
            Utility.shell("brew install wget")
        }
        if !FileManager.default.fileExists(atPath: (URL.currentDirectory + "srt-\(version)").path) {
            Utility.shell("curl -L https://github.com/Haivision/srt/archive/refs/tags/v\(version).tar.gz | tar xj")
        }
        super.buildALL()
    }

    override func innerBuid(platform: PlatformType, arch: ArchType, cflags _: String, buildDir: URL) {
        let opensslPath = URL.currentDirectory + ["SSL", platform.rawValue, "thin", arch.rawValue]
        let directoryURL = URL.currentDirectory + "srt-\(version)"
        let cmakeDir = directoryURL + "\(platform)-\(arch)"

        if !FileManager.default.fileExists(atPath: cmakeDir.path) {
            try? FileManager.default.createDirectory(at: cmakeDir, withIntermediateDirectories: false, attributes: nil)
        }

        let srtPlatform = toSRTPlatform(platform: platform)

        let pkgConfigPath = "\(opensslPath.path)/lib/pkgconfig:"
        let environment = ["PKG_CONFIG_PATH": pkgConfigPath]
        let thinDirPath = thinDir(platform: platform, arch: arch).path
        let command = "cmake .. -DCMAKE_PREFIX_PATH=\(thinDirPath) -DCMAKE_INSTALL_PREFIX=\(thinDirPath) -DCMAKE_TOOLCHAIN_FILE=scripts/iOS.cmake -DIOS_ARCH=\(arch) -DIOS_PLATFORM=\(srtPlatform)  -DCMAKE_IOS_DEVELOPER_ROOT=\(platform.crossTop()) -D_CMAKE_IOS_SDK_ROOT=\(platform.crossSDK())"
        Utility.shell(command, currentDirectoryURL: cmakeDir, environment: environment)
        Utility.shell("make >>\(buildDir.path).log && make install >>\(buildDir.path).log ", currentDirectoryURL: cmakeDir)
    }

    override func frameworks() -> [String] {
        ["Libsrt"]
    }

    private func toSRTPlatform(platform: PlatformType) -> String {
        switch platform {
        case .ios:
            return "OS"
        case .isimulator:
            return "SIMULATOR64"
        default:
            let message = "Platform not supported: \(platform)"
            print(message)
            return message
        }
    }
}

private class BuildOpenSSL: BaseBuild {
    private let sslFile = "openssl-3.0.6"
    init() {
        super.init(library: "SSL")
    }

    override func buildALL() {
        if !FileManager.default.fileExists(atPath: (URL.currentDirectory + sslFile).path) {
            Utility.shell("curl https://www.openssl.org/source/\(sslFile).tar.gz | tar xj")
        }
        super.buildALL()
    }

    override func architectures(_ platform: PlatformType) -> [ArchType] {
        let archs = super.architectures(platform)
        if platform == .ios, archs.contains(.arm64e) {
            return archs.filter { $0 != .arm64 }
        } else {
            return archs
        }
    }

    override func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {
        let directoryURL = URL.currentDirectory + sslFile
        var ccFlags = "/usr/bin/clang " + cflags
        if platform == .macos || platform == .maccatalyst {
            ccFlags += " -fno-common"
        } else {
            ccFlags += " -isysroot \(platform.isysroot())"
        }
        if platform == .tvos || platform == .tvsimulator {
            ccFlags += " -DHAVE_FORK=0"
        }
        let target = platform.target(arch: arch)
        let environment = ["LC_CTYPE": "C", "CROSS_TOP": platform.crossTop(), "CROSS_SDK": platform.crossSDK(), "CC": ccFlags]
        let command = "./Configure " + target +
            " no-async no-shared no-dso no-engine no-tests --prefix=\(thinDir(platform: platform, arch: arch).path) --openssldir=\(buildDir.path) >>\(buildDir.path).log"
        Utility.shell(command, currentDirectoryURL: directoryURL, environment: environment)
        Utility.shell("make clean >>\(buildDir.path).log && make >>\(buildDir.path).log && make -j8 install_sw >>\(buildDir.path).log ", currentDirectoryURL: directoryURL, environment: environment)
    }

    override func frameworks() -> [String] {
        ["Libcrypto", "Libssl"]
    }
}

private class BuildBoringSSL: BaseBuild {
    private let sslFile = "boringssl"
    init() {
        super.init(library: "SSL")
    }

    override func buildALL() {
        if !FileManager.default.fileExists(atPath: (URL.currentDirectory + sslFile).path) {
            Utility.shell("git clone https://github.com/google/boringssl.git")
        }
        super.buildALL()
    }

    override func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {
        var command = "cmake -DCMAKE_OSX_SYSROOT=\(platform.sdk().lowercased()) -DCMAKE_OSX_ARCHITECTURES=\(arch.rawValue)"
        if platform == .maccatalyst {
            command = "cmake -DCMAKE_C_FLAGS='\(cflags)'"
        }
        command += " -GNinja ../../../../boringssl"
        Utility.shell(command, currentDirectoryURL: buildDir)
        Utility.shell("ninja >>\(buildDir.path).log", currentDirectoryURL: buildDir)
        let thin = thinDir(platform: platform, arch: arch)
        try? FileManager.default.createDirectory(at: thin + "lib", withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.copyItem(at: URL.currentDirectory + [sslFile, "include"], to: thin + "include")
        try? FileManager.default.copyItem(at: buildDir + ["ssl", "libssl.a"], to: thin + ["lib", "libssl.a"])
        try? FileManager.default.copyItem(at: buildDir + ["crypto", "libcrypto.a"], to: thin + ["lib", "libcrypto.a"])
    }

    override func frameworks() -> [String] {
        ["Libcrypto", "Libssl"]
    }
}

private enum PlatformType: String, CaseIterable {
    private static let xcodePath = Utility.shell("xcode-select -p", isOutput: true) ?? ""
    case ios, isimulator, tvos, tvsimulator, macos, maccatalyst
    var minVersion: String {
        switch self {
        case .ios, .isimulator:
            return "13.0"
        case .tvos, .tvsimulator:
            return "13.0"
        case .macos:
            return "10.15"
        case .maccatalyst:
            return "13.0"
        }
    }

    func architectures() -> [ArchType] {
        switch self {
        case .ios:
            return [.arm64, .arm64e]
        case .tvos:
            return [.arm64]
        case .isimulator, .tvsimulator:
            return [.arm64, .x86_64]
        case .macos:
            return [.arm64, .x86_64]
        case .maccatalyst:
            return [.arm64, .x86_64]
        }
    }

    func deploymentTarget(_ arch: ArchType) -> String {
        switch self {
        case .ios:
            return "-mios-version-min=\(minVersion)"
        case .isimulator:
            return "-mios-simulator-version-min=\(minVersion)"
        case .tvos:
            return "-mtvos-version-min=\(minVersion)"
        case .tvsimulator:
            return "-mtvos-simulator-version-min=\(minVersion)"
        case .macos:
            return "-mmacosx-version-min=\(minVersion)"
        case .maccatalyst:
            return arch == .x86_64 ? "-target x86_64-apple-ios-macabi" : "-target arm64-apple-ios-macabi"
        }
    }

    func sdk() -> String {
        switch self {
        case .ios:
            return "iPhoneOS"
        case .isimulator:
            return "iPhoneSimulator"
        case .tvos:
            return "AppleTVOS"
        case .tvsimulator:
            return "AppleTVSimulator"
        case .macos:
            return "MacOSX"
        case .maccatalyst:
            return "iPhoneOS"
        }
    }

    func crossSDK() -> String {
        if self == .maccatalyst {
            return PlatformType.macos.crossSDK()
        } else {
            return sdk() + ".sdk"
        }
    }

    func crossTop() -> String {
        if self == .maccatalyst {
            return PlatformType.macos.crossTop()
        } else {
            return "\(PlatformType.xcodePath)/Platforms/\(sdk()).platform/Developer"
        }
    }

    func isysroot() -> String {
        crossTop() + "/SDKs/" + crossSDK()
    }

    func cpu(arch: ArchType) -> String {
        switch arch {
        case .arm64:
            return "--cpu=armv8"
        case .x86_64:
            return "--cpu=x86_64"
        case .arm64e:
            return "--cpu=armv8.3-a"
        }
    }

    func target(arch: ArchType) -> String {
        if arch == .x86_64 {
            return "darwin64-x86_64-cc"
        } else {
            if self == .macos || self == .tvsimulator || self == .isimulator {
                return "darwin64-arm64-cc"
            } else if self == .ios {
                return "ios64-cross"
            } else {
                return "iphoneos-cross"
            }
        }
        // switch self {
        //     case .ios:
        //         return "ios-cros-\(arch)"
        //     case .isimulator:
        //         return "ios64-sim-cross-\(arch)"
        //     case .tvos:
        //         return "tvos64-cross-\(arch)"
        //     case .tvsimulator:
        //         return "tvos-sim-cross--\(arch)"
        //     case .macos:
        //         return "macos-\(arch)"
        //     case .maccatalyst:
        //         return "mac-catalyst-\(arch)"
        // }
    }
}

enum ArchType: String, CaseIterable {
    // swiftlint:disable identifier_name
    case arm64, x86_64, arm64e
    // swiftlint:enable identifier_name
    func executable() -> Bool {
        guard let architecture = Bundle.main.executableArchitectures?.first?.intValue else {
            return false
        }
        #if os(macOS)
        if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
            if architecture == NSBundleExecutableArchitectureARM64, self == .arm64 {
                return true
            }
        }
        #endif
        if architecture == NSBundleExecutableArchitectureX86_64, self == .x86_64 {
            return true
        }
        return false
    }

    func arch() -> String {
        switch self {
        case .arm64, .arm64e:
            return "aarch64"
        case .x86_64:
            return "x86_64"
        }
    }
}

enum Utility {
    @discardableResult
    static func shell(_ command: String, isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) -> String? {
        #if os(macOS)
        let task = Process()
        var environment = environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = environment
        task.currentDirectoryURL = currentDirectoryURL
        let pipe = Pipe()
//        task.standardError = pipe
        if isOutput {
            task.standardOutput = pipe
        }
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            if isOutput {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
            } else {
                return ""
            }
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }

//    @discardableResult
//    static func exec(_ args: [String], currentDirectoryURL: URL? = nil) -> String? {
//        let task = Process()
//        task.environment = ["PATH": "/bin:/usr/bin:/usr/local/bin"]
//        if #available(OSX 10.13, *) {
//            task.currentDirectoryURL = currentDirectoryURL
//        }
//        let pipe = Pipe()
//        task.standardOutput = pipe
//        task.launchPath = "/usr/bin/env"
//        task.arguments = args
//        task.launch()
//        task.waitUntilExit()
//        if task.terminationStatus == 0 {
//            let data = pipe.fileHandleForReading.readDataToEndOfFile()
//            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
//        } else {
//            return nil
//        }
//    }
}

extension URL {
    static var currentDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func + (left: URL, right: String) -> URL {
        var url = left
        url.appendPathComponent(right)
        return url
    }

    static func + (left: URL, right: [String]) -> URL {
        var url = left
        right.forEach {
            url.appendPathComponent($0)
        }
        return url
    }
}
