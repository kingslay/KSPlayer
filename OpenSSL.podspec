Pod::Spec.new do |s|
    s.name             = 'OpenSSL'
    s.version          = '3.0.1'
    s.summary          = 'OpenSSL'

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
    s.default_subspec = 'OpenSSL'
    s.static_framework = true
    s.subspec 'OpenSSL' do |openssl|
        openssl.vendored_frameworks = 'Sources/Libssl.xcframework', 'Sources/Libcrypto.xcframework'
    end
end
