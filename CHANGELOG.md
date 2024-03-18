## 1.2.4
- [iOS & macOS] Fixed an isseu which caused the first advertisement not to be broadcast.

## 1.2.3
- [Android] Fixed requestPermission not working correctly.

## 1.2.2
- [Android] Fixed serviceUuid not working. (thanks @Shik1266 !)
- [Android] Updated compileSdk to 34.

## 1.2.1
- Fix build errors & crash on Windows
- Upgrade gradle to 8.1

## 1.2.0
Improvements:
- Added support for windows
- Updated bluetooth permissions system for Android, no need for permission handler anymore.
- Updated dependencies and several other small improvements.

## 1.1.1
Bugs fixed:
- Fixed an issue which caused the enableBluetooth function to reply twice.
- Fixed analyzer issues
- Upgraded dependencies

## 1.1.0
Upgraded android sdk to 33.
Added permission check on enableBluetooth function. 

## 1.0.0
Stable release including the changes noted in the beta releases.
This release also updates Android dependencies.

## 1.0.0-beta.2
Fixed macOS version not working

## 1.0.0-beta.1
BREAKING CHANGES:
You now define the data to be advertised using the AdvertiseData() constructor.
AdvertiseData is the only supported object in iOS. AdvertiseSettings and other objects are only
supported on Android.

NEW:
* You can now make use of the new startAdvertisingSet parameter on Android 26+

## 0.6.0
* Refactored large parts of the code for both Android & iOS.
* Upgraded Android to Android 12 permission system.
* Other minor improvements

## 0.5.0+1
Changes of 0.5.0 weren't visible on pub.dev

## 0.5.0
Added isSupported function to check if BLE advertising is supported by the device.

## 0.4.2
Fixed typo causing deviceName not to broadcast on iOS

## 0.4.1
Fixed bug on iOS which led to crash
Added local name to advertising in iOS
Updated Android dependencies

## 0.4.0
Added new options to AdvertiseData
Removed embedding V1 for Android

## 0.3.0
Upgraded to null-safety
Updated dependencies
Changed to pedantic

Bug fixes
* Fixed null-pointer when bluetooth adapter isn't found

## 0.2.0
Add support for MacOS

## 0.1.0
Fixed several parts for Android:
* Advertising local name
* Advertising Manufacturer Data
* Advertising Service Data

## 0.0.4
Fixed iOS advertising not working

## 0.0.3
Fixed callback on Android

## 0.0.2
Fixed flutter v2 embedding

## 0.0.1
Initial version of the library. This version includes:
* broadcasting a custom UUID
