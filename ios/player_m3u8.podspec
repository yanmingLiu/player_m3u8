#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint player_m3u8.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'player_m3u8'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for HLS/m3u8 playback.'
  s.description      = <<-DESC
Texture-based HLS/m3u8 playback for iOS and Android Flutter apps.
                       DESC
  s.homepage         = 'https://example.com/player_m3u8'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'player_m3u8' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'player_m3u8_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
