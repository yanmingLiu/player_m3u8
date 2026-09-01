#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint player_m3u8.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'player_m3u8'
  s.version          = '0.1.4'
  s.summary          = 'A Flutter plugin for HLS/m3u8 playback.'
  s.description      = <<-DESC
Texture-based HLS/m3u8 playback for iOS and Android Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/yanmingLiu/player_m3u8'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'player_m3u8' => 'noreply@example.com' }
  s.source           = {
    :git => 'https://github.com/yanmingLiu/player_m3u8.git',
    :tag => s.version.to_s
  }
  s.source_files = 'player_m3u8/Sources/player_m3u8/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'player_m3u8_privacy' => ['player_m3u8/Sources/player_m3u8/PrivacyInfo.xcprivacy']
  }
end
