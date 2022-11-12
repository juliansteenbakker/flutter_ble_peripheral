#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_ble_peripheral.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_ble_peripheral'
  s.version          = '1.0.0'
  s.summary          = 'This plugin enables a device to be set into peripheral mode, and advertise custom
                          services and characteristics.'
  s.description      = <<-DESC
This plugin enables a device to be set into peripheral mode, and advertise custom
  services and characteristics.
                       DESC
  s.homepage         = 'https://steenbakker.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
