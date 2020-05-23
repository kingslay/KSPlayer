Pod::Spec.new do |s|
    s.name             = 'KSPlayer'
    s.version          = '1.0'
    s.summary          = 'Video Player Using Swift, based on AVPlayer,FFmpeg'

    s.description      = <<-DESC
    Video Player Using Swift, based on ffmpeg, support for the horizontal screen, vertical screen, the upper and lower slide to adjust the volume, the screen brightness, or so slide to adjust the playback progress.
    DESC

    s.homepage         = 'https://github.com/kingslay/KSPlayer'
    s.authors = { 'kintan' => '554398854@qq.com' }
    s.license          = 'MIT'
    s.source           = { :git => 'https://github.com/kingslay/KSPlayer.git', :tag => s.version.to_s }

    s.ios.deployment_target = '10.0'
    s.osx.deployment_target = '10.12'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '10.2'
    s.swift_version = '5.2'
    s.static_framework = true
    s.subspec 'UXKit' do |ss|
        ss.source_files = 'Sources/UXKit/*.{swift}'
        ss.ios.source_files = 'Sources/UXKit/iOS/*.swift'
        ss.tvos.source_files = 'Sources/UXKit/iOS/*.swift'
        ss.osx.source_files = 'Sources/UXKit/macOS/*.swift'
        ss.frameworks = 'Foundation'
    end
    s.subspec 'Basic' do |ss|
        ss.source_files = 'Sources/Basic/*.{swift}'
        ss.dependency 'KSPlayer/UXKit'
    end
    s.subspec 'Subtitle' do |ss|
        ss.source_files = 'Sources/Subtitle/*.{swift}'
        ss.frameworks = 'Foundation'
    end
    s.subspec 'FFmpeg' do |ffmpeg|
#        ffmpeg.public_header_files = 'Sources/FFmpeg/**/*.{h}'
        ffmpeg.source_files = 'Sources/FFmpegExt/**/*.{h,c}'
        ffmpeg.libraries   = 'bz2', 'z', 'iconv', 'xml2'
        ffmpeg.ios.xcconfig = {
            'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg.xcframework/ios-arm64/FFmpeg.framework/Headers ${PODS_ROOT}/../../FFmpeg/FFmpeg.xcframework/ios-arm64/FFmpeg.framework/Headers"
        }
        ffmpeg.tvos.xcconfig = {
            'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg.xcframework/tvos-arm64/FFmpeg.framework/Headers ${PODS_ROOT}/../../FFmpeg/FFmpeg.xcframework/tvos-arm64/FFmpeg.framework/Headers"
        }
        ffmpeg.osx.xcconfig = {
            'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg.xcframework/macos-x86_64/FFmpeg.framework/Headers ${PODS_ROOT}/../../FFmpeg/FFmpeg.xcframework/macos-x86_64/FFmpeg.framework/Headers"
        }
        ffmpeg.vendored_frameworks = 'FFmpeg/FFmpeg.xcframework'
        ffmpeg.dependency 'Openssl'
    end
    s.subspec 'Metal' do |ss|
        ss.source_files = 'Sources/Metal/*.{h,swift,metal}'
        ss.resource_bundles = {
            'Metal' => ['Sources/Metal/*.metal']
        }
        ss.weak_framework = 'MetalKit'
    end
    #AVPlayer播放内核
    s.subspec 'AVPlayer' do |ss|
        ss.source_files = 'Sources/AVPlayer/*.{swift}'
        ss.frameworks = 'AVFoundation'
        ss.dependency 'KSPlayer/Basic'
    end
    #ffmpeg播放内核
    s.subspec 'MEPlayer' do |ss|
        ss.source_files = 'Sources/MEPlayer/**/*.{swift}'
        ss.frameworks  = 'AudioToolbox', 'VideoToolbox'
        ss.dependency 'KSPlayer/FFmpeg'
        ss.dependency 'KSPlayer/AVPlayer'
        ss.dependency 'KSPlayer/Metal'
        ss.dependency 'KSPlayer/Subtitle'
    end
  
    s.subspec 'Core' do |ss|
        ss.source_files = 'Sources/Core/*'
        ss.ios.source_files = 'Sources/Core/iOS/*.swift'
        ss.tvos.source_files = 'Sources/Core/iOS/*.swift'
        ss.osx.source_files = 'Sources/Core/macOS/*.swift'
        ss.dependency 'KSPlayer/AVPlayer'
        ss.resource_bundles = {
            'KSResources' => ['Sources/Core/Resources/*']
        } 
    end
    s.subspec 'Audio'do |ss|
        ss.source_files = 'Sources/Audio/*.swift'
        ss.ios.source_files = 'Sources/Audio/iOS/*.swift'
        ss.tvos.source_files = 'Sources/Audio/iOS/*.swift'
        ss.osx.source_files = 'Sources/Audio/macOS/*.swift'
        ss.ios.frameworks  = 'UIKit'
        ss.tvos.frameworks  = 'UIKit'
        ss.osx.frameworks  = 'AppKit'
        ss.dependency 'KSPlayer/Core'
        ss.dependency 'KSPlayer/Subtitle'
    end
    s.subspec 'Video' do |ss|
        ss.source_files = 'Sources/Video/*.swift'
        ss.ios.source_files = 'Sources/Video/iOS/*.swift'
        ss.tvos.source_files = 'Sources/Video/tvOS/*.swift', 'Sources/Video/iOS/KSSubtitleView.swift'
        ss.osx.source_files = 'Sources/Video/macOS/*.swift'
        ss.ios.frameworks  = 'UIKit'
        ss.tvos.frameworks  = 'UIKit'
        ss.osx.frameworks  = 'AppKit'
        ss.dependency 'KSPlayer/Core'
        ss.dependency 'KSPlayer/Subtitle'
    end
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = 'Tests/*.swift'
        test_spec.ios.source_files = 'Tests/iOS/*.swift'
        test_spec.tvos.source_files = 'Tests/tvOS/*.swift'
        test_spec.osx.source_files = 'Tests/macOS/*.swift'
        test_spec.resources = 'Tests/Resources/*'
    end    
end
