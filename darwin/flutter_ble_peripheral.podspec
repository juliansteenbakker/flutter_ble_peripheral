#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_ble_peripheral.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_ble_peripheral'
  s.version          = '2.0.1'
  s.summary          = 'This plugin enables a device to be set into peripheral mode, and advertise custom
                          services and characteristics.'
  s.description      = <<-DESC
This plugin enables a device to be set into peripheral mode, and advertise custom
  services and characteristics.
                       DESC
  s.homepage         = 'https://github.com/juliansteenbakker/flutter_ble_peripheral'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Julian Steenbakker' => 'juliansteenbakker@outlook.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_ble_peripheral/Sources/flutter_ble_peripheral/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'flutter_ble_peripheral_privacy' => ['flutter_ble_peripheral/Sources/flutter_ble_peripheral/Resources/PrivacyInfo.xcprivacy']}
end
