Pod::Spec.new do |s|
    s.name             = 'FFmpeg'
    s.version          = '4.3.1'
    s.summary          = 'FFmpeg'

    s.description      = <<-DESC
    OpenSSL
    DESC

    s.homepage         = 'https://github.com/kingslay/KSPlayer'
    s.authors = { 'kintan' => '554398854@qq.com' }
    s.license          = 'MIT'
    s.source           = { :git => 'https://github.com/kingslay/KSPlayer.git', :tag => s.version.to_s }

    s.ios.deployment_target = '10.0'
    s.osx.deployment_target = '10.13'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '10.2'
    s.default_subspec = 'FFmpeg'
    s.swift_version = '5.1'
    s.static_framework = true
    s.source_files = 'Sources/FFmpeg/**/*.{h,c,m}'
    s.subspec 'FFmpeg' do |ffmpeg|
        ffmpeg.libraries   = 'bz2', 'z', 'iconv', 'xml2'
        ffmpeg.vendored_frameworks = 'Sources/libavcodec.xcframework','Sources/libavformat.xcframework','Sources/libavutil.xcframework','Sources/libswresample.xcframework','Sources/libswscale.xcframework'
        ffmpeg.dependency 'OpenSSL'
    end
end
