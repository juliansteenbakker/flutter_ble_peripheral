# Migration guide

## 2.x to 3.0.0

Everything to do with advertising was split into a shared core plus one settings
object per platform, so a call site no longer mixes fields that only one platform
honours with fields every platform honours.

| Removed | Replaced with |
| --- | --- |
| `AdvertiseData` | `AdvertiseDataCore` for the cross-platform fields, `AndroidAdvertiseData` for the Android-only ones |
| `AdvertiseData.includePowerLevel` | `includeTxPowerLevel`, which every platform that supports it now reads |
| `start(advertiseSettings:)`, `start(advertiseSetParameters:)`, `start(advertiseResponseData:)`, `start(advertisePeriodicData:)`, `start(periodicAdvertiseSettings:)` | `start(androidSettings: AndroidAdvertiseSettings(...))`, which holds all five; `advertisePeriodicData` is `periodicAdvertiseData` there |
| `AdvertiseSettings.advertiseSet` | Passing `AndroidAdvertiseSettings.advertiseSetParameters` selects the extended advertising API. It is now mutually exclusive with `advertiseSettings`, where 2.x took both and let `advertiseSet` pick |
| `PermissionState` | `PeripheralBluetoothState`, which covers the same permission cases plus the adapter states |
| `BluetoothPeripheralState` | `PeripheralBluetoothState`, so this package and `flutter_ble_central` no longer declare colliding type names. The old name stays as a deprecated alias in 3.0 and is removed in the next breaking release |

Changed rather than removed:

- `AdvertiseSetParameters.anonymous` is a `bool?`, not an `int?`.
- `AdvertiseSettings` defaults: `timeout` is `0`, meaning no timeout, instead of
  `400`, and `txPowerLevel` is `advertiseTxPowerHigh` instead of
  `advertiseTxPowerLow`.
- `PeripheralState` carries `locationServicesDisabled` again, which shifts the
  index of every entry after it. Switch on the values, not on `.values[i]`.
- The files under `lib/src` moved into `core/` and `platform/<platform>/`. Only a
  direct `package:flutter_ble_peripheral/src/...` import breaks; everything is
  still exported from `package:flutter_ble_peripheral/flutter_ble_peripheral.dart`.

Before:

```dart
await FlutterBlePeripheral().start(
  advertiseData: AdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    localName: 'My peripheral',
    includePowerLevel: true,
    includeDeviceName: true,
  ),
  advertiseSettings: AdvertiseSettings(advertiseSet: false, timeout: 400),
  advertiseResponseData: AdvertiseData(includeDeviceName: true),
);
```

After:

```dart
await FlutterBlePeripheral().start(
  advertiseData: const AndroidAdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    localName: 'My peripheral',
    includeTxPowerLevel: true,
    includeDeviceName: true,
  ),
  androidSettings: const AndroidAdvertiseSettings(
    advertiseSettings: AdvertiseSettings(timeout: 400),
    advertiseResponseData: AndroidAdvertiseData(includeDeviceName: true),
  ),
);
```

For the extended path, pass `advertiseSetParameters` instead of
`advertiseSettings`, which is where periodic advertising lives:

```dart
androidSettings: const AndroidAdvertiseSettings(
  advertiseSetParameters: AdvertiseSetParameters(),
  periodicAdvertiseData: AndroidAdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
  ),
  periodicAdvertiseSettings: PeriodicAdvertiseSettings(),
),
```

Apart from what is listed above, `AdvertiseSettings`, `AdvertiseSetParameters` and
`PeriodicAdvertiseSettings` keep their names and fields; they moved inside
`AndroidAdvertiseSettings` rather than sitting on `start()`. `DarwinAdvertiseSettings` and `WindowsAdvertiseSettings` are
the equivalents for the other platforms. Drop `AndroidAdvertiseData` for
`AdvertiseDataCore` if the call site does not set any of the Android-only fields.

`PermissionState` has no alias on purpose. Its entries are declared in a different
order than `PeripheralBluetoothState`'s, and these values cross the platform
channel by ordinal, so mapping the old values across by index gives the wrong
state rather than a compile error.
