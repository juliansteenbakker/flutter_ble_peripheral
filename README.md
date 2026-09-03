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

To keep advertising once the app is no longer in front, add the background mode to
`ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-peripheral</string>
</array>
```

Without it iOS stops the advertisement when the app leaves the foreground. What it
does to the advertisement that stays on air, and what the plugin does with the key
beyond that, is under [Background advertising](#background-advertising). macOS has no
background modes, and keeps advertising for as long as the app runs.

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

Pass `characteristics` to serve a layout of your own instead of the TX and RX pair,
of any size and with the properties you choose. A heart rate peripheral is one
notifying characteristic:

```dart
await peripheral.start(
  advertiseData: const AdvertiseDataCore(serviceUuid: '180d'),
  gattServer: const GattServerSettings(
    characteristics: [
      GattCharacteristic.notify('2a37'),
    ],
  ),
);

// The flags byte, then the bpm as a uint8.
await peripheral.sendData(Uint8List.fromList([0x00, 72]));
```

`GattCharacteristic.notify` and `GattCharacteristic.write` are the two shapes the
default pair uses; the unnamed constructor takes any set of
`GattCharacteristicProperty` values, so one characteristic can be both notified on
and written to. The 16 bit, 32 bit and 128 bit uuid forms are all accepted.

With more than one notifying characteristic, `sendData` needs to be told which one it
is delivering on, and answers with a `SEND_FAILED` `PlatformException` if it is not:

```dart
await peripheral.sendData(bytes, characteristicUuid: '2a37');
```

Which characteristic a write landed on comes through `onGattWrite`, and
`onCharacteristicSubscriptionChanged` reports subscriptions per characteristic;
`isSubscribedTo` asks about one of them. `onDataReceived`, `onSubscriptionChanged`
and `isSubscribed` still answer for the service as a whole, so a peripheral serving
one pair needs none of this.

One service is served at a time. A second service cannot be added: on Windows a
service is advertised by its own provider, and several providers on air at once is
not something this package can promise.

`sendData` only reaches a central that subscribed to the characteristic, which is not
the same as one that merely connected, and throws a `PlatformException` when none has.
Watch `onSubscriptionChanged`, or check `isSubscribed`, to know when it can deliver.
Payloads are queued per central, so back-to-back calls arrive in order rather than
overwriting each other, and a central that reads a characteristic gets the payload
sent last on it.

On Windows the service is advertised by the GATT service provider rather than by the
advertisement publisher, which is also what makes the peripheral connectable there and
puts the service uuid on air; a legacy Windows advertisement cannot carry one. Because
the service carries itself, this is also the one case where Windows accepts an
advertisement without manufacturer data or service data. The advertise timeout ends
what the service has on air along with the publisher, leaving it serving whoever is
already connected, the same as an Android advertise timeout does.

### Background advertising

On Android the advertisement belongs to the process, so it keeps going while the app
sits in the background and ends when the system kills the process. Advertising from a
service rather than from an activity is not supported yet: `start()` needs an activity
to check permissions against, and answers with a `No activity` error without one.

On iOS the advertisement ends with the foreground unless the app declares the
`bluetooth-peripheral` background mode. With it, Core Bluetooth keeps advertising, but
not the advertisement that was passed in:

- The local name is dropped.
- The service uuids move into the overflow area, where only an iOS central that scans
  for those exact uuids can see them. A scan with no uuid filter, and every non-Apple
  scanner, sees nothing at all. This is the usual reason background advertising looks
  broken: it is on air, but nothing that is looking for it broadly will report it.
- Advertising is slower and shares the radio with whatever else the system is doing.

Declaring the background mode also lets the plugin register a restore identifier with
Core Bluetooth, which is what allows iOS to relaunch the app into the background and
hand back the advertisement and the GATT service, including the centrals that were
subscribed to TX. The state, mtu and subscription streams replay their last value to a
new listener, so an app that comes back this way sees `advertising` or `connected` on
`onPeripheralStateChanged` and can carry on with `sendData` without calling `start()`
again. Calling it again is safe: the advertisement is replaced rather than rejected,
and a service that already matches is left in place, so a central stays connected
across it.

### Streams

| Stream | Type | Description |
| --- | --- | --- |
| `onPeripheralStateChanged` | `PeripheralState` | Adapter and advertising state |
| `onMtuChanged` | `int` | Negotiated MTU, after a central connects |
| `onSubscriptionChanged` | `bool` | Whether a central is subscribed to TX |
| `onDataReceived` | `Uint8List` | Bytes a central wrote to a writable characteristic |
| `onGattWrite` | `GattWrite` | As above, with the characteristic it landed on |
| `onCharacteristicSubscriptionChanged` | `GattSubscription` | Per-characteristic subscription changes |

## API

| Member | Returns | Description |
| --- | --- | --- |
| `start({advertiseData, ...})` | `PeripheralBluetoothState` | Starts advertising |
| `stop()` | `PeripheralBluetoothState` | Stops advertising |
| `isSupported` | `bool` | Whether BLE advertising is available on this device |
| `isAdvertising` | `bool` | Whether an advertisement is running |
| `isConnected` | `bool` | Whether a central is connected (Android and Apple) |
| `isSubscribed` | `bool` | Whether a central subscribed to any notifying characteristic, so `sendData` can deliver |
| `isSubscribedTo(uuid)` | `bool` | As above, for one characteristic |
| `sendData(Uint8List, {characteristicUuid})` | `void` | Notifies the centrals subscribed to that characteristic |
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
