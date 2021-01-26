Pod::Spec.new do |s|
    s.name             = 'KSPlayer'
    s.version          = '1.0'
    s.summary          = 'Video Player Using Swift, based on AVPlayer,FFmpeg'

    s.description      = <<-DESC
    Video Player Using Swift, based on ffmpeg, support for the horizontal screen, vertical screen, the upper and lower slide to adjust the volume, the screen brightness, or so slide to adjust the playback progress.
    DESC

    s.homepage         = 'https://github.com/kingslay/KSPlayer'
    s.authors = { 'kintan' => 'kingslay@icloud.com' }
    s.license          = 'MIT'
    s.source           = { :git => 'https://github.com/kingslay/KSPlayer.git', :tag => s.version.to_s }

    s.ios.deployment_target = '10.0'
    s.osx.deployment_target = '10.12'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '10.2'
    s.swift_version = '5.2'
    s.static_framework = true
    s.subspec 'UXKit' do |ss|
        ss.source_files = 'Sources/KSPlayer/UXKit/*.{swift}'
        ss.frameworks = 'Foundation'
    end
    s.subspec 'Basic' do |ss|
        ss.source_files = 'Sources/KSPlayer/Basic/*.{swift}'
        ss.dependency 'KSPlayer/UXKit'
    end
    s.subspec 'Subtitle' do |ss|
        ss.source_files = 'Sources/KSPlayer/Subtitle/*.{swift}'
        ss.frameworks = 'Foundation'
    end
    s.subspec 'Metal' do |ss|
        ss.source_files = 'Sources/KSPlayer/Metal/*.{swift,metal}'
        ss.resource_bundles = {
            'Metal' => ['Sources/KSPlayer/Metal/*.metal']
        }
        ss.weak_framework = 'MetalKit'
    end
    #AVPlayer播放内核
    s.subspec 'AVPlayer' do |ss|
        ss.source_files = 'Sources/KSPlayer/AVPlayer/*.{swift}'
        ss.frameworks = 'AVFoundation'
        ss.ios.frameworks  = 'UIKit'
        ss.tvos.frameworks  = 'UIKit'
        ss.osx.frameworks  = 'AppKit'
        ss.dependency 'KSPlayer/Basic'
    end
    #ffmpeg播放内核
    s.subspec 'MEPlayer' do |ss|
        ss.source_files = 'Sources/KSPlayer/MEPlayer/**/*.{swift}'
        ss.frameworks  = 'AudioToolbox', 'VideoToolbox'
        ss.dependency 'FFmpeg'
        ss.dependency 'KSPlayer/AVPlayer'
        ss.dependency 'KSPlayer/Metal'
        ss.dependency 'KSPlayer/Subtitle'
    end
  
    s.subspec 'Core' do |ss|
        ss.source_files = 'Sources/KSPlayer/Core/*'
        ss.dependency 'KSPlayer/AVPlayer'
        ss.resource_bundles = {
            'KSResources' => ['Sources/KSPlayer/Core/Resources/*']
        } 
    end
    s.subspec 'Audio'do |ss|
        ss.source_files = 'Sources/KSPlayer/Audio/*.swift'
        ss.dependency 'KSPlayer/Core'
        ss.dependency 'KSPlayer/Subtitle'
    end
    s.subspec 'Video' do |ss|
        ss.source_files = 'Sources/KSPlayer/Video/*.swift'
        ss.dependency 'KSPlayer/Core'
        ss.dependency 'KSPlayer/Subtitle'
    end
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = 'Tests/KSPlayerTests/*.swift'
        test_spec.resources = 'Tests/KSPlayerTests/Resources/*'
    end    
end
