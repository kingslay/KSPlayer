Pod::Spec.new do |s|
    s.name             = 'Openssl'
    s.version          = '1.1.1'
    s.summary          = 'Openssl'

    s.description      = <<-DESC
    Openssl
    DESC

    s.homepage         = 'https://github.com/kingslay/KSPlayer'
    s.authors = { 'kintan' => '554398854@qq.com' }
    s.license          = 'MIT'
    s.source           = { :git => 'https://github.com/kingslay/KSPlayer.git', :tag => s.version.to_s }

    s.ios.deployment_target = '9.0'
    s.osx.deployment_target = '10.11'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '10.2'
    s.default_subspec = 'Openssl'
    s.swift_version = '5.1'
    s.static_framework = true
    s.subspec 'Openssl' do |openssl|
        openssl.vendored_frameworks = 'Sources/OpenSSL.xcframework'
    end
end
