Pod::Spec.new do |s|
    s.name             = 'FFmpeg'
    s.version          = '5.0'
    s.summary          = 'FFmpeg'

    s.description      = <<-DESC
    OpenSSL
    DESC

    s.homepage         = 'https://github.com/kingslay/KSPlayer'
    s.authors = { 'kintan' => '554398854@qq.com' }
    s.license          = 'MIT'
    s.source           = { :git => 'https://github.com/kingslay/KSPlayer.git', :tag => s.version.to_s }

    s.ios.deployment_target = '11.0'
    s.osx.deployment_target = '10.13'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '11.0'
    s.default_subspec = 'FFmpeg'
    s.static_framework = true
    s.source_files = 'Sources/FFmpeg/**/*.{h,c,m}'
    s.subspec 'FFmpeg' do |ffmpeg|
        ffmpeg.libraries   = 'bz2', 'z', 'iconv', 'xml2'
        ffmpeg.vendored_frameworks = 'Sources/Libavcodec.xcframework','Sources/Libavfilter.xcframework','Sources/Libavformat.xcframework','Sources/Libavutil.xcframework','Sources/Libswresample.xcframework','Sources/Libswscale.xcframework'
        ffmpeg.dependency 'OpenSSL'
    end
end
