import Foundation

let array = Array(CommandLine.arguments.dropFirst())
let isDebug = array.firstIndex(of: "debug") != nil
let xcodePath = Utility.shell("xcode-select -p", isOutput: true) ?? ""
BuildOpenSSL().buildALL()
// BuildBoringSSL().buildALL()
BuildFFMPEG().buildALL()
open class BaseBuild {
    private let platforms = PlatformType.allCases
//    private let platforms = [PlatformType.maccatalyst, PlatformType.macos]
    private let library: String
    init(library: String) {
        self.library = library
    }
    func buildALL() {
        for platform in platforms {
            for arch in platform.architectures() {
                build(platform: platform, arch: arch)
            }
        }
        createXCFramework()
    }

    func build(platform: PlatformType, arch: ArchType) {
        let url = Utility.splice(paths: [library, platform.rawValue, "scratch", arch.rawValue])
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        var cflags = "-arch \(arch.rawValue) \(platform.deploymentTarget())"
        cflags += " -fembed-bitcode"
        innerBuid(platform: platform, arch: arch, cflags: cflags, buildDir: url)
    }
    func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {

    }
    func createXCFramework() {
        for framework in frameworks() {
            var arguments = ""
            let XCFrameworkFile = Utility.splice(paths: ["../Sources", framework + ".xcframework"])
            try? FileManager.default.removeItem(at: XCFrameworkFile)
            for platform in platforms {
                arguments += " -framework \(createFramework(framework: framework, platform: platform, archs: platform.architectures()))"
            }
            Utility.shell("xcodebuild -create-xcframework\(arguments) -output \(XCFrameworkFile.path)")
        }
    }
    private func createFramework(framework: String, platform: PlatformType, archs: [ArchType]) -> String {
        let frameworkDir = Utility.splice(paths: [library, platform.rawValue, "\(framework).framework"])
        try? FileManager.default.removeItem(at: frameworkDir)
        try? FileManager.default.createDirectory(at: frameworkDir, withIntermediateDirectories: true, attributes: nil)
        var command = "lipo -create"
        for arch in archs {
            let prefix = thinDir(platform: platform, arch: arch)
            command += " "
            command += (prefix + "lib/\(framework).a").path
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
        let modulemap = "framework module \(framework) [system] {\n   \(frameworkHeader(framework))\n    export *\n}"
        FileManager.default.createFile(atPath: frameworkDir.path + "/Modules/module.modulemap", contents: modulemap.data(using: .utf8), attributes: nil)
        createPlist(path: frameworkDir.path+"/Info.plist", name: framework, minVersion: platform.minVersion, platform: platform.sdk())
        return frameworkDir.path
    }
    func thinDir(platform: PlatformType, arch: ArchType) -> URL {
        return Utility.splice(paths: [library, platform.rawValue, "thin", arch.rawValue])
    }
    func frameworks() -> [String] {
        return []
    }

    func frameworkHeader(_ framework: String) -> String {
        return "header \"\(framework.replacingOccurrences(of: "Lib", with: "")).h\""
    }

    func createPlist(path: String, name: String, minVersion: String, platform: String) {
        let identifier = "com.kintan.ksplayer." + name
        var content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>${FRAMEWORK_NAME}</string>
        <key>CFBundleIdentifier</key>
        <string>${FRAMEWORK_ID}</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>${FRAMEWORK_NAME}</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>87.88.520</string>
        <key>CFBundleVersion</key>
        <string>87.88.520</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>MinimumOSVersion</key>
        <string>${MinimumOSVersion}</string>
        <key>CFBundleSupportedPlatforms</key>
        <array>
        <string>${CFBundleSupportedPlatforms}</string>
        </array>
        <key>NSPrincipalClass</key>
        <string></string>
        </dict>
        </plist>
        """
        content = content.replacingOccurrences(of: "${FRAMEWORK_NAME}", with: name)
        content = content.replacingOccurrences(of: "${FRAMEWORK_ID}", with: identifier)
        content = content.replacingOccurrences(of: "${MinimumOSVersion}", with: minVersion)
        content = content.replacingOccurrences(of: "${CFBundleSupportedPlatforms}", with: platform)
        FileManager.default.createFile(atPath: path, contents: content.data(using: .utf8), attributes: nil)
    }
}

class BuildFFMPEG: BaseBuild {
    private let ffmpegFile = "ffmpeg-4.3.2"
    init() {
        super.init(library: "FFmpeg")
    }
    override func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {
        var ffmpegcflags = ffmpegConfiguers
        if isDebug && platform == .macos {
            ffmpegcflags.append("--enable-ffmpeg")
            ffmpegcflags.append("--enable-ffplay")
            ffmpegcflags.append("--enable-sdl2")
            ffmpegcflags.append("--enable-encoder=mpeg4")
            ffmpegcflags.append("--enable-encoder=aac")
            ffmpegcflags.append("--enable-muxer=m4v")
            ffmpegcflags.append("--enable-muxer=dash")
        } else {
            ffmpegcflags.append("--disable-debug")
            ffmpegcflags.append("--disable-programs")
            ffmpegcflags.append("--disable-ffmpeg")
            ffmpegcflags.append("--disable-ffplay")
            ffmpegcflags.append("--disable-ffprobe")
            ffmpegcflags.append("--disable-avfilter")
            ffmpegcflags.append("--disable-filters")
        }
        if platform == .isimulator || platform == .tvsimulator {
            ffmpegcflags.append("--assert-level=1")
        } else if platform == .ios {
            ffmpegcflags.append("--enable-small")
        }
        if platform == .maccatalyst {
            ffmpegcflags.append("--disable-asm")
        }
        var cflags = cflags
        var ldflags = "-arch \(arch.rawValue)"
        if platform == .maccatalyst {
            let syslibroot = platform.isysroot()
            cflags += " -isysroot \(syslibroot) -iframework \(syslibroot)/System/iOSSupport/System/Library/Frameworks"
            ldflags = cflags
        }
        let opensslPath = Utility.splice(paths: ["SSL", platform.rawValue, "thin", arch.rawValue])
        if FileManager.default.fileExists(atPath: opensslPath.path) {
            cflags += " -I\(opensslPath.path)/include"
            ldflags += " -L\(opensslPath.path)/lib"
            ffmpegcflags.append("--enable-openssl")
        }
        let prefix = thinDir(platform: platform, arch: arch)
        var args = ["set -o noglob &&", Utility.splice(paths: [ffmpegFile, "configure"]).path, "--target-os=darwin",
                    "--arch=\(arch)", "--cc='xcrun -sdk \(platform.sdk().lowercased()) clang'",
                    "--extra-cflags='\(cflags)'", "--extra-ldflags='\(ldflags)'", "--prefix=\(prefix.path)"]
        args.append(contentsOf: ffmpegcflags)
        print(args.joined(separator: " "))
        Utility.shell(args.joined(separator: " "), currentDirectoryURL: buildDir)
        Utility.shell("make -j8 install\(arch == .x86_64 ? "" : " GASPP_FIX_XCODE5=1") >>\(buildDir.path).log", currentDirectoryURL: buildDir)
        if isDebug && platform == .macos && arch.executable() {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffplay"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffprobe"))
            try? FileManager.default.copyItem(at: Utility.splice(paths: ["bin", "ffmpeg"], current: prefix), to: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"))
            try? FileManager.default.copyItem(at: Utility.splice(paths: ["bin", "ffplay"], current: prefix), to: URL(fileURLWithPath: "/usr/local/bin/ffplay"))
            try? FileManager.default.copyItem(at: Utility.splice(paths: ["bin", "ffprobe"], current: prefix), to: URL(fileURLWithPath: "/usr/local/bin/ffprobe"))
        }
    }
    override func frameworks() -> [String] {
        return ["Libavcodec", "Libavformat", "Libavutil", "Libswresample", "Libswscale"]
    }
    override func buildALL() {
        prepareYasm()
        if !FileManager.default.fileExists(atPath: Utility.splice(paths: [ffmpegFile]).path) {
            Utility.shell("curl http://www.ffmpeg.org/releases/\(ffmpegFile).tar.bz2 | tar xj")
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
    }
    override func frameworkHeader(_ framework: String) -> String {
        if framework == "Libavutil" {
            return super.frameworkHeader(framework) + "\n    header \"display.h\"\n    header \"imgutils.h\""
        } else {
            return super.frameworkHeader(framework)
        }
    }
    private let ffmpegConfiguers = [
        "--enable-optimizations", "--enable-gpl", "--enable-version3", "--enable-nonfree",
        // Configuration options:
        "--enable-cross-compile", "--enable-stripping", "--enable-libxml2", "--enable-thumb",
        "--enable-static", "--disable-shared", "--enable-runtime-cpudetect", "--disable-gray", "--disable-swscale-alpha",
        // Documentation options:
        "--disable-doc", "--disable-htmlpages", "--disable-manpages", "--disable-podpages", "--disable-txtpages",
        // Component options:
        "--disable-avdevice", "--enable-avcodec", "--enable-avformat", "--enable-avutil",
        "--enable-swresample", "--enable-swscale", "--disable-postproc", "--disable-avresample",
        // ,"--disable-pthreads"
        // ,"--disable-w32threads"
        // ,"--disable-os2threads"
        "--enable-network",
        // ,"--disable-dct"
        // ,"--disable-dwt"
        // ,"--disable-lsp"
        // ,"--disable-lzo"
        // ,"--disable-mdct"
        // ,"--disable-rdft"
        // ,"--disable-fft"
        // Hardware accelerators:
        "--disable-d3d11va", "--disable-dxva2", "--disable-vaapi", "--disable-vdpau",
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
        "--enable-decoder=aac", "--enable-decoder=aac_latm", "--enable-decoder=ac3", "--enable-decoder=alac",
        "--enable-decoder=amrnb", "--enable-decoder=amrwb", "--enable-decoder=ape", "--enable-decoder=cook",
        "--enable-decoder=dca", "--enable-decoder=eac3", "--enable-decoder=flac", "--enable-decoder=mp1",
        "--enable-decoder=mp2", "--enable-decoder=mp3*", "--enable-decoder=opus", "--enable-decoder=pcm*",
        "--enable-decoder=wma*", "--enable-decoder=vorbis", "--enable-decoder=truehd", "--enable-decoder=dolby_e",
        // 字幕
        "--enable-decoder=ass", "--enable-decoder=srt", "--enable-decoder=ssa", "--enable-decoder=movtext",
        "--enable-decoder=subrip", "--enable-decoder=dvdsub", "--enable-decoder=dvbsub", "--enable-decoder=webvtt", "--disable-hwaccels",
        // ./configure --list-muxers
        "--disable-muxers",
        // ,"--enable-muxer=mpegts"
        // ,"--enable-muxer=mp4"
        // ./configure --list-demuxers
        "--disable-demuxers", "--enable-demuxer=aac", "--enable-demuxer=concat", "--enable-demuxer=data", "--enable-demuxer=flv", "--enable-demuxer=hls",
        // "--enable-demuxer=latm",
        "--enable-demuxer=live_flv", "--enable-demuxer=loas", "--enable-demuxer=m4v", "--enable-demuxer=mov",
        "--enable-demuxer=mp3", "--enable-demuxer=mpegps", "--enable-demuxer=mpegts", "--enable-demuxer=mpegvideo",
        "--enable-demuxer=hevc", "--enable-demuxer=dash", "--enable-demuxer=wav", "--enable-demuxer=ogg",
        "--enable-demuxer=ape", "--enable-demuxer=aiff", "--enable-demuxer=flac", "--enable-demuxer=amr",
        "--enable-demuxer=rtsp", "--enable-demuxer=asf", "--enable-demuxer=avi", "--enable-demuxer=matroska",
        "--enable-demuxer=rm", "--enable-demuxer=vc1",
        // "--enable-demuxer=webm_dash_manifest",

        // ./configure --list-protocols
        "--enable-protocols", "--disable-protocol=bluray", "--disable-protocol=ffrtmpcrypt", "--disable-protocol=gopher",
        "--disable-protocol=icecast", "--disable-protocol=librtmp*", "--disable-protocol=libssh",
        "--disable-protocol=md5", "--disable-protocol=mmsh", "--disable-protocol=mmst", "--disable-protocol=sctp",
        "--disable-protocol=srtp", "--disable-protocol=subfile", "--disable-protocol=unix",
        "--disable-devices", "--disable-indevs", "--disable-outdevs", "--disable-iconv", "--disable-bsfs",
        "--disable-audiotoolbox", "--disable-videotoolbox", "--disable-linux-perf", "--disable-bzlib"]
}

class BuildOpenSSL: BaseBuild {
    private let sslFile = "openssl-1.1.1i"
    init() {
        super.init(library: "SSL")
    }
    override func buildALL() {
        if !FileManager.default.fileExists(atPath: Utility.splice(paths: [sslFile]).path) {
            Utility.shell("curl https://www.openssl.org/source/\(sslFile).tar.gz | tar xj")
        }
        super.buildALL()
    }
    override func innerBuid(platform: PlatformType, arch: ArchType, cflags: String, buildDir: URL) {
        let directoryURL = Utility.splice(paths: [sslFile])
        var ccFlags = "/usr/bin/clang " + cflags
        if platform == .macos || platform == .maccatalyst {
            ccFlags += " -fno-common"
        } else {
            ccFlags += " -isysroot \(platform.isysroot())"
        }
        let target = platform.target(arch: arch)
        let environment = ["LC_CTYPE": "C", "CROSS_TOP": platform.crossTop(), "CROSS_SDK": platform.crossSDK(), "CC": ccFlags]
        let args = ["./Configure", target, "--prefix=\(thinDir(platform: platform, arch: arch).path)", "no-asm no-async no-shared", "--openssldir=\(buildDir.path)", ">>\(buildDir.path).log"]
        Utility.shell(args.joined(separator: " "), currentDirectoryURL: directoryURL, environment: environment)
        Utility.shell("make >>\(buildDir.path).log", currentDirectoryURL: directoryURL, environment: environment)
        Utility.shell("make install_sw >>\(buildDir.path).log", currentDirectoryURL: directoryURL, environment: environment)
        Utility.shell("make clean >>\(buildDir.path).log", currentDirectoryURL: directoryURL, environment: environment)
    }
    override func frameworks() -> [String] {
        return ["Libcrypto", "Libssl"]
    }
    override func frameworkHeader(_ framework: String) -> String {
        return "header \"openssl/\(framework.replacingOccurrences(of: "Lib", with: "")).h\""
    }
}

class BuildBoringSSL: BaseBuild {
    private let sslFile = "boringssl"
    init() {
        super.init(library: "SSL")
    }
    override func buildALL() {
        if !FileManager.default.fileExists(atPath: Utility.splice(paths: [sslFile]).path) {
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
        try? FileManager.default.copyItem(at: Utility.splice(paths: [sslFile, "include"]), to: thin + "include")
        try? FileManager.default.copyItem(at: buildDir + "ssl/libssl.a", to: thin + "lib/libssl.a")
        try? FileManager.default.copyItem(at: buildDir + "crypto/libcrypto.a", to: thin + "lib/libcrypto.a")
    }
    override func frameworks() -> [String] {
        return ["Libcrypto", "Libssl"]
    }
    override func frameworkHeader(_ framework: String) -> String {
        return "header \"openssl/\(framework.replacingOccurrences(of: "Lib", with: "")).h\""
    }
}
enum PlatformType: String, CaseIterable {
    case ios, isimulator, tvos, tvsimulator, macos, maccatalyst
    var minVersion: String {
        switch self {
        case .ios, .isimulator:
            return "10.0"
        case .tvos, .tvsimulator:
            return "10.2"
        case .macos:
            return "10.13"
        case .maccatalyst:
            return "13.0"
        }
    }
    func architectures() -> [ArchType] {
        switch self {
        case .ios:
            return [.arm64]
        case .tvos:
            return [.arm64]
        case .isimulator, .tvsimulator:
            return [.arm64, .x86_64]
        case .macos:
            return [.arm64, .x86_64]
        case .maccatalyst:
            return [.x86_64]
        }
    }
    func os() -> String {
        switch self {
        case .isimulator:
            return "ios"
        case .tvsimulator:
            return "tvos"
        default:
        return self.rawValue
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
            return sdk()+".sdk"
        }
    }
    func crossTop() -> String {
        if self == .maccatalyst {
            return PlatformType.macos.crossTop()
        } else {
            return "\(xcodePath)/Platforms/\(sdk()).platform/Developer"
        }
    }
    func isysroot() -> String {
        return crossTop() + "/SDKs/" + crossSDK()
    }
    func target(arch: ArchType) -> String {
        if arch == .arm64 && (self == .macos || self == .tvsimulator || self == .isimulator) {
            return "darwin64-arm64-cc"
        } else {
            if arch == .x86_64 {
                return "darwin64-x86_64-cc"
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
        if #available(OSX 11.0, *) {
            if architecture == NSBundleExecutableArchitectureARM64 && self == .arm64 {
                return true
            }
        }
        if architecture == NSBundleExecutableArchitectureX86_64 && self == .x86_64 {
            return true
        }
        return false
    }
}

struct Utility {

    @discardableResult
    static func shell(_ command: String, isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) -> String? {
        let task = Process()
        var environment = environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = environment
        if #available(OSX 10.13, *) {
            task.currentDirectoryURL = currentDirectoryURL
        }
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
    static func splice(paths: [String], current: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
        var url = current
        paths.forEach {
            url.appendPathComponent($0)
        }
        return url
    }
}
extension URL {
    static func + (left: URL, right: String) -> URL {
        var url = left
        url.appendPathComponent(right)
        return url
    }
}
