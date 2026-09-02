# flutter_ble_peripheral

[![pub package](https://img.shields.io/pub/v/flutter_ble_peripheral?include_prereleases)](https://pub.dev/packages/flutter_ble_peripheral)
[![CI](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/juliansteenbakker/flutter_ble_peripheral/actions/workflows/ci.yml)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
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

Upgrading from 2.x? See [MIGRATION.md](MIGRATION.md).

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

Every permission call returns a `PeripheralBluetoothState`, which covers both the
permission result and the state of the adapter.

```dart
if (!await peripheral.isSupported) return;

var state = await peripheral.hasPermission();
if (state != PeripheralBluetoothState.granted) {
  state = await peripheral.requestPermission();
}

switch (state) {
  case PeripheralBluetoothState.granted:
  case PeripheralBluetoothState.ready:
    break;
  case PeripheralBluetoothState.turnedOff:
    await peripheral.enableBluetooth();      // Android and Windows only
    break;
  case PeripheralBluetoothState.permanentlyDenied:
    await peripheral.openAppSettings();
    break;
  default:
    return;
}
```

### Advertising

```dart
await peripheral.start(
  advertiseData: AdvertiseDataCore(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    localName: 'My peripheral',
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([1, 2, 3]),
  ),
);

// later
await peripheral.stop();
```

`start` returns a `PeripheralBluetoothState`, so an advertisement that could not be
started because Bluetooth is off or unsupported is reported rather than thrown.

`AdvertiseDataCore` carries what more than one platform can advertise: the service
uuids, the local name, the manufacturer data and the TX power flag. Not every
platform carries all of them:

- Apple broadcasts only the service uuids and the local name, and limits the name to
  about 10 bytes.
- Android ignores `localName`; use `AndroidAdvertiseData.includeDeviceName` to
  broadcast the system name instead.
- Windows carries only the manufacturer data and the service data, one of which has
  to be set unless a `gattServer` is served alongside it. A legacy Windows
  advertisement refuses to start at all when it sets a local name or service uuids,
  so both are validated and then left off the air.

### Platform settings

Anything a single platform supports lives on that platform's class, passed alongside
the shared data and ignored on the others.

```dart
await peripheral.start(
  advertiseData: const AdvertiseDataCore(localName: 'My peripheral'),
  androidSettings: const AndroidAdvertiseSettings(
    advertiseSettings: AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeLowLatency,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
      connectable: true,
      timeout: 400,
    ),
  ),
);
```

| Class | Carries |
| --- | --- |
| `AndroidAdvertiseData` | Service data, the device name flag, a solicitation uuid |
| `AndroidAdvertiseSettings` | Advertise settings or set parameters, scan response and periodic data |
| `DarwinAdvertiseSettings` | Overflow and solicited service uuids |
| `WindowsAdvertiseSettings` | Advertise timeout, advertisement flags, extended advertising, preferred TX power |

`AndroidAdvertiseData` extends `AdvertiseDataCore`, so pass it as `advertiseData` when
you need the Android-only fields.

On Android 8.0 and above, passing `AndroidAdvertiseSettings.advertiseSetParameters`
switches to the extended advertising API instead of the legacy one.

Android and Windows each carry their own advertise timeout, because the rules differ:
`AdvertiseSettings.timeout` applies on Android's legacy path only, since an
advertising set is limited by `AdvertiseSetParameters.duration` instead, while
`WindowsAdvertiseSettings.timeout` applies either way, since a Windows publisher has
no per-set duration to end it. Apple has no equivalent.

### GATT server

Pass `gattServer` to serve a service alongside the advertisement. It holds a TX
characteristic the peripheral notifies on and an RX characteristic the central writes
to.

```dart
await peripheral.start(
  advertiseData: const AdvertiseDataCore(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
  ),
  gattServer: const GattServerSettings(),
);

peripheral.onDataReceived.listen((bytes) {
  // A central wrote to the RX characteristic.
});

await peripheral.sendData(Uint8List.fromList([1, 2, 3]));
```

The service uuid defaults to the advertised one. The characteristic uuids default to
the Nordic UART Service pair, exported as `defaultTxCharacteristicUuid` and
`defaultRxCharacteristicUuid`, so a central that knows that profile can talk to the
peripheral without being told them out of band. Pass your own to serve a different
layout. They are never derived from the service uuid, because a central caches the
GATT database between connections and a characteristic uuid that moves breaks the
link.

`sendData` only reaches a central that subscribed to TX, which is not the same as one
that merely connected, and throws a `PlatformException` when none has. Watch
`onSubscriptionChanged`, or check `isSubscribed`, to know when it can deliver.
Payloads are queued per central, so back-to-back calls arrive in order rather than
overwriting each other, and a central that reads TX gets the payload sent last.

On Windows the service is advertised by the GATT service provider rather than by the
advertisement publisher, which is also what makes the peripheral connectable there and
puts the service uuid on air; a legacy Windows advertisement cannot carry one. Because
the service carries itself, this is also the one case where Windows accepts an
advertisement without manufacturer data or service data. The advertise timeout ends
what the service has on air along with the publisher, leaving it serving whoever is
already connected, the same as an Android advertise timeout does.

### Streams

| Stream | Type | Description |
| --- | --- | --- |
| `onPeripheralStateChanged` | `PeripheralState` | Adapter and advertising state |
| `onMtuChanged` | `int` | Negotiated MTU, after a central connects |
| `onSubscriptionChanged` | `bool` | Whether a central is subscribed to TX |
| `onDataReceived` | `Uint8List` | Bytes a central wrote to the RX characteristic |

## API

| Member | Returns | Description |
| --- | --- | --- |
| `start({advertiseData, ...})` | `PeripheralBluetoothState` | Starts advertising |
| `stop()` | `PeripheralBluetoothState` | Stops advertising |
| `isSupported` | `bool` | Whether BLE advertising is available on this device |
| `isAdvertising` | `bool` | Whether an advertisement is running |
| `isConnected` | `bool` | Whether a central is connected (Android and Apple) |
| `isSubscribed` | `bool` | Whether a central subscribed to TX, so `sendData` can deliver |
| `sendData(Uint8List)` | `void` | Notifies the subscribed centrals on the TX characteristic |
| `isBluetoothOn` | `bool` | Whether the adapter is powered on |
| `hasPermission()` | `PeripheralBluetoothState` | Current permission and adapter state |
| `requestPermission()` | `PeripheralBluetoothState` | Prompts for the required permissions |
| `enableBluetooth({askUser})` | `bool` | Turns the adapter on (Android and Windows) |
| `openBluetoothSettings()` | `void` | Opens the system Bluetooth settings |
| `openAppSettings()` | `void` | Opens this app's settings page |
| `isNearbyShareEnabled()` | `bool` | Windows only, `false` elsewhere |
| `openNearbyShareSettings()` | `void` | Windows only, no-op elsewhere |
| `openLocationSettings()` | `void` | Windows only, no-op elsewhere |

## Example

The [example app](example/README.md) covers advertising, the GATT server, permissions
and adapter state, laid out over four pages, and hosts a game of pong over the link it
serves. Run it with `cd example && flutter run`.

It is the peripheral half of a pair. Run the
[flutter_ble_central](https://github.com/juliansteenbakker/flutter_ble_central)
example on a second device to connect to it and exchange bytes in both directions;
see [the example README](example/README.md#running-the-pair).

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
branch layout, commit conventions and release process.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
