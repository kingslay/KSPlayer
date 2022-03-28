import Foundation
@main
class BaseBuild {
    fileprivate static let argumentsArray = Array(CommandLine.arguments.dropFirst())
    static func main() {
        let path = URL.currentDirectory + "Script"
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: false, attributes: nil)
        }
        FileManager.default.changeCurrentDirectoryPath(path.path)
        let onlyFFmpeg = argumentsArray.firstIndex(of: "only-ffmpeg") != nil
        if !onlyFFmpeg {
            BuildOpenSSL().buildALL()
            // BuildBoringSSL().buildALL()
        }
        BuildFFMPEG().buildALL()
    }

    fileprivate let platforms = PlatformType.allCases
//     fileprivate let platforms = [PlatformType.tvos]
    private let library: String
    init(library: String) {
        self.library = library
    }

    func buildALL() {
        try? FileManager.default.removeItem(at: URL.currentDirectory + library)
        for platform in platforms {
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
        let cflags = "-arch " + arch.rawValue + " -fembed-bitcode " + platform.deploymentTarget()
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
            for platform in platforms {
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

class BuildFFMPEG: BaseBuild {
    private let ffmpegFile = "ffmpeg-5.0"
    private let isDebug: Bool
    private let isFFplay: Bool
    init() {
        isDebug = BaseBuild.argumentsArray.firstIndex(of: "debug") != nil
        isFFplay = BaseBuild.argumentsArray.firstIndex(of: "ffplay") != nil
        super.init(library: "FFmpeg")
    }

    override func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {
        var ffmpegcflags = ffmpegConfiguers
        if !isDebug {
            ffmpegcflags.append("--disable-debug")
        }
        if isFFplay, platform == .macos, arch.executable() {
            ffmpegcflags.append("--enable-ffmpeg")
            ffmpegcflags.append("--enable-ffplay")
            ffmpegcflags.append("--enable-sdl2")
            ffmpegcflags.append("--enable-encoder=mpeg4")
            ffmpegcflags.append("--enable-encoder=aac")
            ffmpegcflags.append("--enable-muxer=m4v")
            ffmpegcflags.append("--enable-muxer=dash")
        } else {
            ffmpegcflags.append("--disable-programs")
            ffmpegcflags.append("--disable-ffmpeg")
            ffmpegcflags.append("--disable-ffplay")
            ffmpegcflags.append("--disable-ffprobe")
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
        if FileManager.default.fileExists(atPath: opensslPath.path) {
            cflags += " -I\(opensslPath.path)/include"
            ldflags += " -L\(opensslPath.path)/lib"
            ffmpegcflags.append("--enable-openssl")
        }
        let prefix = thinDir(platform: platform, arch: arch)
        var args = ["set -o noglob &&", (URL.currentDirectory + [ffmpegFile, "configure"]).path, "--target-os=darwin",
                    "--arch=\(arch.arch())", platform.cpu(arch: arch), "--cc='xcrun -sdk \(platform.sdk().lowercased()) clang'",
                    "--extra-cflags='\(cflags)'", "--extra-ldflags='\(ldflags)'", "--prefix=\(prefix.path)"]
        args.append(contentsOf: ffmpegcflags)
        print(args.joined(separator: " "))
        Utility.shell(args.joined(separator: " "), currentDirectoryURL: buildDir)
        Utility.shell("make -j8 install\(arch == .x86_64 ? "" : " GASPP_FIX_XCODE5=1") >>\(buildDir.path).log", currentDirectoryURL: buildDir)
        if isFFplay, platform == .macos, arch.executable() {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffplay"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffprobe"))
            try? FileManager.default.copyItem(at: prefix + ["bin", "ffmpeg"], to: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"))
            try? FileManager.default.copyItem(at: prefix + ["bin", "ffplay"], to: URL(fileURLWithPath: "/usr/local/bin/ffplay"))
            try? FileManager.default.copyItem(at: prefix + ["bin", "ffprobe"], to: URL(fileURLWithPath: "/usr/local/bin/ffprobe"))
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
        guard let platform = platforms.first, let arch = platform.architectures().first else {
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
        prepareYasm()
        if !FileManager.default.fileExists(atPath: (URL.currentDirectory + ffmpegFile).path) {
            Utility.shell("curl http://www.ffmpeg.org/releases/\(ffmpegFile).tar.bz2 | tar xj")
        }
        let path = URL.currentDirectory + ffmpegFile + "libavcodec/videotoolbox.c"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "kCVPixelBufferOpenGLESCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            str = str.replacingOccurrences(of: "kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            try? str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
        super.buildALL()
    }

    private func prepareYasm() {
        if Utility.shell("which brew") == nil {
            Utility.shell("ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)\"")
        }
        if Utility.shell("which yasm") == nil {
            Utility.shell("brew install yasm")
        }
        if Utility.shell("which pkg-config") == nil {
            Utility.shell("brew install pkg-config")
        }
        if isFFplay, Utility.shell("which sdl2-config") == nil {
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
        "--enable-optimizations", "--disable-xlib", "--disable-devices", "--disable-indevs", "--disable-outdevs",
        "--disable-iconv", "--disable-shared", "--disable-gray", "--disable-swscale-alpha",
        "--disable-bsfs", "--disable-symver", "--disable-armv5te", "--disable-armv6", " --disable-armv6t2",
        "--disable-linux-perf", "--disable-bzlib", "--disable-small",
        "--enable-gpl", "--enable-version3", "--enable-nonfree", "--enable-static", "--enable-runtime-cpudetect",
        "--enable-cross-compile", "--enable-stripping", "--enable-libxml2", "--enable-thumb",
        // Documentation options:
        "--disable-doc", "--disable-htmlpages", "--disable-manpages", "--disable-podpages", "--disable-txtpages",
        // Component options:
        "--disable-avdevice", "--enable-avcodec", "--enable-avformat", "--enable-avutil",
        "--enable-swresample", "--enable-swscale", "--disable-postproc", "--enable-network",
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
        "--disable-encoders",
        // ./configure --list-decoders
        "--disable-decoders", "--enable-decoder=dca", "--enable-decoder=flv", "--enable-decoder=h263",
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
        "--enable-decoder=mp1*", "--enable-decoder=mp2*", "--enable-decoder=mp3*", "--enable-decoder=opus", "--enable-decoder=pcm*",
        "--enable-decoder=truehd", "--enable-decoder=vorbis", "--enable-decoder=wma*",
        // 字幕
        "--enable-decoder=ass", "--enable-decoder=dvbsub", "--enable-decoder=dvdsub", "--enable-decoder=movtext",
        "--enable-decoder=pgssub", "--enable-decoder=srt", "--enable-decoder=ssa", "--enable-decoder=subrip", "--enable-decoder=webvtt",
        // ./configure --list-muxers
        "--disable-muxers",
        // "--enable-muxer=mpegts", "--enable-muxer=mp4",
        // ./configure --list-demuxers
        "--disable-demuxers", "--enable-demuxer=aac", "--enable-demuxer=ac3", "--enable-demuxer=aiff", "--enable-demuxer=amr",
        "--enable-demuxer=asf", "--enable-demuxer=ape", "--enable-demuxer=avi",
        "--enable-demuxer=concat", "--enable-demuxer=dash", "--enable-demuxer=data", "--enable-demuxer=eac3",
        "--enable-demuxer=flac", "--enable-demuxer=flv", "--enable-demuxer=h264", "--enable-demuxer=hevc", "--enable-demuxer=hls",
        "--enable-demuxer=live_flv", "--enable-demuxer=loas",
        "--enable-demuxer=m4v", "--enable-demuxer=matroska", "--enable-demuxer=mov", "--enable-demuxer=mp3", "--enable-demuxer=mpeg*",
        "--enable-demuxer=ogg", "--enable-demuxer=rm", "--enable-demuxer=rtsp",
        "--enable-demuxer=vc1", "--enable-demuxer=wav",
        // "--enable-demuxer=latm",
        // "--enable-demuxer=webm_dash_manifest",
        // ./configure --list-protocols
        "--enable-protocols", "--disable-protocol=bluray", "--disable-protocol=ffrtmpcrypt", "--disable-protocol=gopher",
        "--disable-protocol=icecast", "--disable-protocol=librtmp*", "--disable-protocol=libssh",
        "--disable-protocol=md5", "--disable-protocol=mmsh", "--disable-protocol=mmst", "--disable-protocol=sctp",
        "--disable-protocol=srtp", "--disable-protocol=subfile", "--disable-protocol=unix",

        // filters
        "--disable-filters", "--enable-filter=amix", "--enable-filter=anull", "--enable-filter=aformat",
        "--enable-filter=aresample", "--enable-filter=areverse", "--enable-filter=asetrate", "--enable-filter=atempo", "--enable-filter=atrim",
        "--enable-filter=format", "--enable-filter=fps", "--enable-filter=hflip", "--enable-filter=null",
        "--enable-filter=overlay", "--enable-filter=palettegen", "--enable-filter=paletteuse", "--enable-filter=pan",
        "--enable-filter=rotate", "--enable-filter=setpts", "--enable-filter=scale",
        "--enable-filter=trim", "--enable-filter=transpose", "--enable-filter=vflip", "--enable-filter=volume",
        "--enable-filter=yadif",
//        "--enable-filter=yadif_videotoolbox",
    ]
}

class BuildOpenSSL: BaseBuild {
    private let sslFile = "openssl-3.0.2"
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
        Utility.shell("make clean >>\(buildDir.path).log && make >>\(buildDir.path).log && make install_sw >>\(buildDir.path).log ", currentDirectoryURL: directoryURL, environment: environment)
    }

    override func frameworks() -> [String] {
        ["Libcrypto", "Libssl"]
    }
}

class BuildBoringSSL: BaseBuild {
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

enum PlatformType: String, CaseIterable {
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

    func frameworkFileName() -> String {
        switch self {
        case .ios:
            return "ios-" + architectures().map(\.rawValue).joined(separator: "_")
        case .isimulator:
            return "ios-" + architectures().map(\.rawValue).joined(separator: "_") + "-simulator"
        case .tvos:
            return "tvos-" + architectures().map(\.rawValue).joined(separator: "_")
        case .tvsimulator:
            return "tvos-" + architectures().map(\.rawValue).joined(separator: "_") + "-simulator"
        case .macos:
            return "macos-" + architectures().map(\.rawValue).joined(separator: "_")
        case .maccatalyst:
            return "ios-" + architectures().map(\.rawValue).joined(separator: "_") + "-maccatalyst"
        }
    }

    func os() -> String {
        switch self {
        case .isimulator:
            return "ios"
        case .tvsimulator:
            return "tvos"
        default:
            return rawValue
        }
    }

    func deploymentTarget() -> String {
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
            return "-target x86_64-apple-ios13.0-macabi"
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
            return "--cpu=armv8 --enable-neon --enable-asm"
        case .x86_64:
            // aacpsdsp.o), building for Mac Catalyst, but linking in object file built for
            // x86_64 binaries are built without ASM support, since ASM for x86_64 is actually x86 and that confuses `xcodebuild -create-xcframework`
            return self == .maccatalyst ? "--cpu=x86_64 --disable-neon --disable-asm" : "--cpu=x86_64 --enable-neon --enable-asm"
        case .arm64e:
            return "--cpu=armv8.3-a --enable-neon --enable-asm"
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
