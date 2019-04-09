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

    s.ios.deployment_target = '9.0'
    s.osx.deployment_target = '10.11'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '10.2'
    s.swift_version = '5.0'
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
    s.subspec 'SubtitleCore' do |ss|
        ss.source_files = 'Sources/SubtitleCore/*.{swift}'
        ss.frameworks = 'Foundation'
    end
    s.subspec 'Subtitle' do |ss|
        ss.source_files = 'Sources/Subtitle/*.{swift}'
        ss.ios.source_files = 'Sources/Subtitle/iOS/*.swift'
        ss.tvos.source_files = 'Sources/Subtitle/iOS/*.swift'
        ss.osx.source_files = 'Sources/Subtitle/macOS/*.swift'
        ss.ios.frameworks  = 'UIKit'
        ss.tvos.frameworks  = 'UIKit'
        ss.osx.frameworks  = 'AppKit'
        ss.dependency 'KSPlayer/Basic'
        ss.dependency 'KSPlayer/SubtitleCore'
        ss.dependency 'KSPlayer/Resources'
    end
    # s.subspec 'Openssl' do |openssl|
    #     openssl.ios.vendored_libraries  = 'FFmpeg/openssl-iOS/lib/*.a'
    #     openssl.ios.preserve_paths = 'FFmpeg/openssl-iOS/include'
    #     openssl.tvos.vendored_libraries  = 'FFmpeg/openssl-tvOS/lib/*.a'
    #     openssl.tvos.preserve_paths = 'FFmpeg/openssl-tvOS/include'
    #     openssl.osx.vendored_libraries  = 'FFmpeg/openssl-macOS/lib/*.a'
    #     openssl.osx.preserve_paths = 'FFmpeg/openssl-macOS/include'
    # end
    s.subspec 'FFmpeg' do |ffmpeg|
        ffmpeg.public_header_files = 'Sources/FFmpeg/**/*.{h}'
        ffmpeg.source_files = 'Sources/FFmpeg/**/*.{c,h}'
        ffmpeg.libraries   = 'bz2', 'z'
        ffmpeg.ios.vendored_libraries  = 'FFmpeg/FFmpeg-iOS/lib/*.a'
        ffmpeg.ios.preserve_paths = 'FFmpeg/FFmpeg-iOS/include'
        ffmpeg.tvos.vendored_libraries  = 'FFmpeg/FFmpeg-tvOS/lib/*.a'
        ffmpeg.tvos.preserve_paths = 'FFmpeg/FFmpeg-tvOS/include'
        ffmpeg.osx.vendored_libraries  = 'FFmpeg/FFmpeg-macOS/lib/*.a'
        ffmpeg.osx.preserve_paths = 'FFmpeg/FFmpeg-macOS/include'
        ffmpeg.ios.xcconfig = {
            'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg-iOS/include ${PODS_ROOT}/../../FFmpeg/FFmpeg-iOS/include",
            'SWIFT_INCLUDE_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg-iOS/include $(PODS_ROOT)/../../FFmpeg/FFmpeg-iOS/include"
        }
        ffmpeg.tvos.xcconfig = {
            'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg-tvOS/include ${PODS_ROOT}/../../FFmpeg/FFmpeg-tvOS/include",
            'SWIFT_INCLUDE_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg-tvOS/include $(PODS_ROOT)/../../FFmpeg/FFmpeg-tvOS/include"
        }
        ffmpeg.osx.xcconfig = {
            'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg-macOS/include ${PODS_ROOT}/../../FFmpeg/FFmpeg-macOS/include",
            'SWIFT_INCLUDE_PATHS' => "${PODS_ROOT}/#{s.name}/FFmpeg/FFmpeg-macOS/include $(PODS_ROOT)/../../FFmpeg/FFmpeg-macOS/include"
        }
        # ffmpeg.dependency 'Openssl'
        ffmpeg.vendored_frameworks = 'Openssl.framework'
    end
    s.subspec 'Metal' do |ss|
        ss.source_files = 'Sources/Metal/*.{swift}'
        ss.weak_framework = 'MetalKit'
    end
    s.subspec 'Panorama' do |ss|
        ss.source_files = 'Sources/Panorama/**/*'
        ss.frameworks  = 'SceneKit','GLKit'
        ss.dependency 'KSPlayer/Basic'
        ss.dependency 'KSPlayer/Metal'
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
        ss.resources = 'Sources/MEPlayer/**/*.{metal,glsl,vsh,fsh}'
        ss.frameworks  = 'AudioToolbox', 'VideoToolbox','GLKit'
        ss.dependency 'KSPlayer/FFmpeg'
        ss.dependency 'KSPlayer/AVPlayer'
        ss.dependency 'KSPlayer/Metal'
        ss.dependency 'KSPlayer/SubtitleCore'
    end
    s.subspec 'VRPlayer' do |ss|
        ss.source_files = 'Sources/VRPlayer/**/*'
        ss.dependency 'KSPlayer/MEPlayer'
        ss.dependency 'KSPlayer/Panorama'
    end
    s.subspec 'Core' do |ss|
        ss.source_files = 'Sources/Core/*'
        ss.ios.source_files = 'Sources/Core/iOS/*.swift'
        ss.tvos.source_files = 'Sources/Core/iOS/*.swift'
        ss.osx.source_files = 'Sources/Core/macOS/*.swift'
        ss.dependency 'KSPlayer/AVPlayer'
        ss.dependency 'KSPlayer/Resources'
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
        ss.dependency 'KSPlayer/SubtitleCore'
    end
    s.subspec 'Video' do |ss|
        ss.source_files = 'Sources/Video/*.swift'
        ss.ios.source_files = 'Sources/Video/iOS/*.swift'
        ss.tvos.source_files = 'Sources/Video/tvOS/*.swift'
        ss.osx.source_files = 'Sources/Video/macOS/*.swift'
        ss.ios.frameworks  = 'UIKit'
        ss.tvos.frameworks  = 'UIKit'
        ss.osx.frameworks  = 'AppKit'
        ss.dependency 'KSPlayer/Core'
        ss.dependency 'KSPlayer/Subtitle'
    end
    s.subspec 'Resources' do |ss|
        ss.resource_bundles = {
            'KSResources' => ['Sources/Resources/*.xcassets']
        }        
    end
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = 'Tests/*.swift'
        test_spec.ios.source_files = 'Tests/iOS/*.swift'
        test_spec.tvos.source_files = 'Tests/tvOS/*.swift'
        test_spec.osx.source_files = 'Tests/macOS/*.swift'
        test_spec.resources = 'Tests/Resources/*'
    end    
end
