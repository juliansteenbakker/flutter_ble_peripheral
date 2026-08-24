# flutter_ble_peripheral

[![pub package](https://img.shields.io/pub/v/flutter_ble_peripheral?include_prereleases)](https://pub.dev/packages/flutter_ble_peripheral)
[![CI](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions/workflows/ci.yml)
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/juliansteenbakker)](https://github.com/sponsors/juliansteenbakker)

Advertise over Bluetooth Low Energy from Flutter. This plugin puts the device in
**peripheral** mode, broadcasting the service UUIDs, manufacturer data and service data
you give it so that nearby centrals can discover it. For the other direction, see
[flutter_ble_central](https://pub.dev/packages/flutter_ble_central).

| Platform | Minimum version | Notes |
| --- | --- | --- |
| Android | API 21 | Full `AdvertiseSettings` support |
| iOS | 13.0 | Only `serviceUuids` and `localName` are broadcast |
| macOS | 10.15 | Only `serviceUuids` and `localName` are broadcast |
| Windows | Windows 10 | Can conflict with Nearby Sharing, see below |

Advertising is a broadcast to everything in range. Treat everything you put in an
advertisement as public.

## Installation

```bash
flutter pub add flutter_ble_peripheral
```

## Platform setup

### Android

The plugin already contributes every permission it needs to your merged manifest:
`BLUETOOTH` and `BLUETOOTH_ADMIN` (both capped at API 30), the API 23–30 location
permissions, and `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` and `BLUETOOTH_SCAN` for
API 31+. `BLUETOOTH_SCAN` is declared with `neverForLocation`.

To drop or change one of them, override it in
`android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:tools="http://schemas.android.com/tools">
    <uses-permission
        android:name="android.permission.ACCESS_FINE_LOCATION"
        tools:node="remove" />
</manifest>
```

### iOS and macOS

Add a usage description to `Info.plist`, or the app is terminated the first time it
touches Bluetooth:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to advertise to nearby devices.</string>
```

On macOS, also tick the Bluetooth entitlement in **both**
`macos/Runner/Release.entitlements` and `macos/Runner/DebugProfile.entitlements`:

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

### Windows

No manifest changes are needed. Windows requires the location permission for BLE, which
`requestPermission()` asks for.

Nearby Sharing can hold the Bluetooth resources that advertising needs, which surfaces as
a `ResourceInUse` failure. Use `isNearbyShareEnabled()` to detect it and
`openNearbyShareSettings()` to send the user to the right settings page.

## Usage

### Getting started

`FlutterBlePeripheral` is a singleton, so calling the constructor anywhere gives you the
same instance.

```dart
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

final peripheral = FlutterBlePeripheral();
```

### Permissions and adapter state

Every permission call returns a `BluetoothPeripheralState`, which covers both the
permission result and the state of the adapter.

```dart
if (!await peripheral.isSupported) return;

var state = await peripheral.hasPermission();
if (state != BluetoothPeripheralState.granted) {
  state = await peripheral.requestPermission();
}

switch (state) {
  case BluetoothPeripheralState.granted:
  case BluetoothPeripheralState.ready:
    break;
  case BluetoothPeripheralState.turnedOff:
    await peripheral.enableBluetooth();      // Android and Windows only
    break;
  case BluetoothPeripheralState.permanentlyDenied:
    await peripheral.openAppSettings();
    break;
  default:
    return;
}
```

### Advertising

```dart
await peripheral.start(
  advertiseData: AdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    localName: 'My peripheral',
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([1, 2, 3]),
  ),
);

// later
await peripheral.stop();
```

`start` returns a `BluetoothPeripheralState`, so an advertisement that could not be
started because Bluetooth is off or unsupported is reported rather than thrown.

`serviceUuid`, `serviceUuids` and `localName` are the only fields Apple platforms
broadcast. Everything else is Android only, and `localName` is limited to 10 bytes on
iOS and macOS.

### Advertise settings

`AdvertiseSettings` mirrors Android's
[`AdvertiseSettings`](https://developer.android.com/reference/android/bluetooth/le/AdvertiseSettings)
and is ignored on the other platforms.

```dart
await peripheral.start(
  advertiseData: AdvertiseData(localName: 'My peripheral'),
  advertiseSettings: AdvertiseSettings(
    advertiseMode: AdvertiseMode.advertiseModeLowLatency,
    txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
    connectable: true,
    timeout: 400,
  ),
);
```

On Android 8.0 and above you can use the extended advertising API instead, by passing
`AdvertiseSetParameters`. `AdvertiseSettings.advertiseSet` controls which of the two
Android APIs is used.

### Streams

| Stream | Type | Description |
| --- | --- | --- |
| `onPeripheralStateChanged` | `PeripheralState` | Adapter and advertising state |
| `onMtuChanged` | `int` | Negotiated MTU, after a central connects |

## API

| Member | Returns | Description |
| --- | --- | --- |
| `start({advertiseData, ...})` | `BluetoothPeripheralState` | Starts advertising |
| `stop()` | `BluetoothPeripheralState` | Stops advertising |
| `isSupported` | `bool` | Whether BLE advertising is available on this device |
| `isAdvertising` | `bool` | Whether an advertisement is running |
| `isConnected` | `bool` | Whether a central is connected (Android and Apple) |
| `isBluetoothOn` | `bool` | Whether the adapter is powered on |
| `sendData(Uint8List)` | `void` | Sends data to the connected central (Apple only) |
| `hasPermission()` | `BluetoothPeripheralState` | Current permission and adapter state |
| `requestPermission()` | `BluetoothPeripheralState` | Prompts for the required permissions |
| `enableBluetooth({askUser})` | `bool` | Turns the adapter on (Android and Windows) |
| `openBluetoothSettings()` | `void` | Opens the system Bluetooth settings |
| `openAppSettings()` | `void` | Opens this app's settings page |
| `isNearbyShareEnabled()` | `bool` | Windows only, `false` elsewhere |
| `openNearbyShareSettings()` | `void` | Windows only, no-op elsewhere |
| `openLocationSettings()` | `void` | Windows only, no-op elsewhere |

## Example

The [example app](example/lib/main.dart) covers permission handling, adapter state and
advertising with custom data. Run it with `cd example && flutter run`.

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
branch layout, commit conventions and release process.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
