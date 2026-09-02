# Changelog

## [3.0.0](https://github.com/juliansteenbakker/flutter_ble_peripheral/compare/v2.1.1...v3.0.0) (2026-09-02)


### ⚠ BREAKING CHANGES

* AdvertiseData is removed. Use AndroidAdvertiseData, which carries the same fields, and includeTxPowerLevel in place of includePowerLevel.
* split the advertising api into core and per-platform settings ([#301](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/301))

### Features

* add a gatt server with tx and rx characteristics ([#260](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/260)) ([bea5601](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/bea560131bbd239e04223097454f265c62ffbef1))
* add the peripheral half of the interop harness ([#308](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/308)) ([90e2e10](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/90e2e103e5db9547d5cc5129a7b7be065b5d8a01))
* honour the advertise timeout on windows ([#299](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/299)) ([0260ef8](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/0260ef8229ee1abfaa2bf688f39293d4e6b2852e))
* keep the old state name as a deprecated alias ([#316](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/316)) ([dc3c389](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/dc3c3894e6e8e359f306eacb3dbb3a7dc45cdad9))
* rebuild the example app and add pong over the gatt link ([#311](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/311)) ([67cdff0](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/67cdff04fc9e2da4cc132227b0013e6095002290))
* remove the deprecated AdvertiseData ([#314](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/314)) ([26fcfdb](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/26fcfdb0f72f5e89bdc3b8ccfdf486d1af692076))
* split the advertising api into core and per-platform settings ([#301](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/301)) ([b88abee](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/b88abeef44a4362a899688cb37875f08c90e4364))
* **windows:** serve a gatt server with tx and rx characteristics ([#302](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/302)) ([fe76ede](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/fe76ede0fc704a57ffc1aed5141048c871553b41))


### Bug Fixes

* advertise serviceUuids on android ([b107d15](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/b107d153ddbbf0b991c720ebc6b88f42605ee888))
* android service uuids not broadcasting ([#285](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/285)) ([b107d15](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/b107d153ddbbf0b991c720ebc6b88f42605ee888))
* **apple:** report peripheral support from core bluetooth, not beacon monitoring ([#309](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/309)) ([76e6405](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/76e6405fea00c27a271031f1a1f79766a928c870))
* **apple:** report the att mtu rather than the notification payload size ([#304](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/304)) ([adfa9d7](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/adfa9d7eeab012a911e85b2f5bc231d8d2f81ad9))
* apply tx power flags and send periodic advertise data on android ([#293](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/293)) ([079274c](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/079274c78151af6ce8d660f8375319bc228d0700))
* build the full advertisement payload on windows ([#297](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/297)) ([881ed5b](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/881ed5bda7c0cb34bf173ec49b9a9db6887d75a0))
* correct the windows state reporting and plugin teardown ([#298](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/298)) ([20b81c9](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/20b81c963a1377d208ed3f0e2e4b04bc0f730dad))
* **example:** defer link meter reports made while the tree is locked ([#313](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/313)) ([fab6ddc](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/fab6ddcb5a6c24402df3873d2589f2bca3525c2b))
* keep isAdvertising true while a central is connected ([#305](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/305)) ([ffe46b4](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/ffe46b427066e2df17a88916ea09719afe20b860))
* only offer a local name where the platform broadcasts one ([#312](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/312)) ([11ea402](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/11ea4027d9bb67b1faaca743cadbb869031f5e1d))
* read advertise byte payloads without casting to ByteArray ([#287](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/287)) ([4832965](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/4832965d94a1e1b6bebba7c6635c98977443ddb4))
* return the advertising state from start on every platform ([#292](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/292)) ([3f0be35](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/3f0be35a6e71d529ada092ca3728c4a1da4ac21b))
* return the converted map from Uint8ListMapStringConverter.toJson ([#295](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/295)) ([6473056](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/6473056589083b96654931d0cb465fadf4b5dd23))
* send the android advertising results from the main thread ([#300](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/300)) ([776aa4a](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/776aa4ad54e3d202712e3b9ab09f54570a61cbf1))
* set advertiseResponseData correctly on Android ([#269](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/269)) ([0e84738](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/0e847381c0a95ba398e4deebc73b9c51716ba321))
* type AdvertiseSetParameters.anonymous as a bool ([#289](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/289)) ([612ec8d](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/612ec8d090f2dcf9d3c4e56b6f09098106e6c22f))
* validate service uuids and advertise once powered on, on apple ([#290](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/290)) ([3135668](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/313566812808f6bde4b0a4ea2813c83bf957ecf3))
* **windows:** align the peripheral state values with the dart enum ([#303](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/303)) ([01e65aa](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/01e65aabdf08a1932e10d907d797ea43ee4c1a2e))
* **windows:** stop a failed radio read from taking the process down ([#307](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/307)) ([0c819cd](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/0c819cdb48bb5d3f2e89890ce6090a51bac4dd85))
* **windows:** wait for the radio lookup before answering isSupported ([#310](https://github.com/juliansteenbakker/flutter_ble_peripheral/issues/310)) ([16d8c3a](https://github.com/juliansteenbakker/flutter_ble_peripheral/commit/16d8c3a59a83f3fd10959e8fc135329d6e6fae78))

## 2.1.1
### Fixes
- [Windows] Fixed crash when Bluetooth adapter is not present or Bluetooth is disabled
- [Windows] Added comprehensive exception handling throughout the plugin to prevent crashes from WinRT API failures
- [Windows] Fixed initial state reporting to correctly show `unsupported` when no Bluetooth adapter is available
- [Windows] Fixed potential crash from type mismatches in method call arguments

## 2.1.0
### New Features
- [iOS/macOS] Added `isBluetoothOn` to check Bluetooth power state
- [iOS/macOS] Added `hasPermission` using `CBPeripheralManager.authorization` API
- [iOS/macOS] Added `requestPermission` support (returns current state, as permissions are implicit on Apple)
- [iOS/macOS] Added `openBluetoothSettings` that opens Bluetooth settings directly
- [Android] Added `isBluetoothOn` to check Bluetooth power state
- [Android] Added Bluetooth state change listener - UI now updates when Bluetooth is toggled while app is open
- [Dart] `hasPermission()` and `requestPermission()` now work on iOS/macOS (previously returned `unknown`)

### Improvements
- [iOS/macOS] `isSupported` now uses peripheral manager state instead of iBeacon check
- [iOS/macOS] Permission and Bluetooth state are now properly separated (permission can be checked regardless of power state)
- [Example] Complete redesign with Material 3 UI
- [Example] Added comprehensive startup checks for: BLE support, permissions, Bluetooth state
- [Example] Platform-specific permission dialogs (Apple shows Settings only, Android shows Grant button)
- [Example] Android permission dialog updates when permanently denied
- [Example] Bluetooth off dialog hides "Turn On" button on Apple (not supported)
- [Windows] Updated build configuration

### Fixes
- [iOS/macOS] `enableBluetooth` now properly returns `false` (not supported on Apple platforms)

## 2.0.1
Fixes naming issues

## 2.0.0
- [Android] Update java and minsdk to latest
- [Apple] Merge of ios and macos codebase
- Complete rewrite of permission system

## 1.2.6
- [Android] Fixes error on start broadcasting

## 1.2.5
- [Android] Added advertiseSet parameter to AdvertiseSettings to enable advertiseSet on Android o and higher devices.

## 1.2.4
- [iOS & macOS] Fixed an issue which caused the first advertisement not to be broadcast.

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
