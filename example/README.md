# Flutter BLE Peripheral Example

Advertises this device as a BLE peripheral and serves a GATT service with a
TX/RX characteristic pair, so a central can connect and exchange bytes in both
directions.

It is the peripheral half of a pair. The other half is the example in
[flutter_ble_central](https://github.com/juliansteenbakker/flutter_ble_central);
see [Running the pair](#running-the-pair) below.

## What it advertises

| | Default | Where |
| --- | --- | --- |
| Service UUID | `bf27730d-860a-4e09-889c-2d8b6a9e0fe7` | Settings, configurable |
| Local name | `Flutter BLE` | Settings, configurable |
| Manufacturer ID and data | `1234`, `01 02 03 04 05 06` | Settings, configurable |
| TX characteristic | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` | `defaultTxCharacteristicUuid` |
| RX characteristic | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` | `defaultRxCharacteristicUuid` |

TX supports read, notify and indicate, and carries what the peripheral sends. RX
supports write and write-without-response, and carries what the central sends.
Both default to the Nordic UART Service characteristics, so a central that knows
that profile finds them without being told the uuids out of band. Pass your own
to `GattServerSettings` to serve a different layout.

The settings can only be changed while advertising is stopped.

## Using it

1. **Permissions** — open the Permissions section and request them. Android
   needs the Bluetooth permissions; Windows needs location.
2. **Advertising** — press Start. The peripheral begins advertising and opens
   the GATT server.
3. **Connect** — the state chip turns to `connected` once a central connects.
4. **Subscribe** — the GATT section reports whether a central has subscribed to
   TX. The Send button stays disabled until one has, because a peripheral cannot
   notify a central that never asked to be notified.
5. **Send** — enter hex bytes such as `01 02 03` and press Send.
6. **Receive** — anything the central writes to RX appears below the Send
   button, most recent first.

The GATT section also shows the negotiated MTU once a central subscribes.

## Running the pair

You need two devices; a phone and a Mac both work, and BLE does not work in a
simulator.

1. Run this example on the first device and press Start.
2. Run the `flutter_ble_central` example on the second device.
3. On the central, scan and connect to `Flutter BLE`. It discovers the service
   and subscribes to TX.
4. On the peripheral, the state chip turns to `connected` and the Send button
   becomes enabled.
5. Send bytes from either side; they appear on the other.

Both examples default to the same service UUID, so they find each other without
any configuration. Change it in one and you have to change it in the other.

## In code

```dart
await FlutterBlePeripheral().start(
  advertiseData: AndroidAdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    localName: 'Flutter BLE',
  ),
  gattServer: const GattServerSettings(),
  androidSettings: const AndroidAdvertiseSettings(
    advertiseSettings: AdvertiseSettings(connectable: true),
  ),
);

FlutterBlePeripheral().onSubscriptionChanged.listen((subscribed) {
  // sendData can only deliver while this is true.
});

FlutterBlePeripheral().onDataReceived.listen((bytes) {
  // A central wrote to the RX characteristic.
});

await FlutterBlePeripheral().sendData(Uint8List.fromList([1, 2, 3]));
```

## Platform support

| | Advertising | GATT server |
| --- | --- | --- |
| Android | yes | yes |
| iOS | yes | yes |
| macOS | yes | yes |
| Windows | yes | not yet |

## Notes

- Stopping advertising closes the GATT server and drops any queued payloads.
- `sendData` queues per central, so back-to-back calls arrive in order rather
  than overwriting each other. It throws when no central is subscribed, rather
  than dropping the payload.
- A central that reads TX gets the payload sent last, so one that subscribes
  late can still pick it up.
- Several centrals can connect at once. The example is written around a single
  one, but `sendData` notifies every subscriber.
- On iOS and macOS `isConnected` is approximate: CoreBluetooth never reports a
  bare connection, so a central only becomes visible once it subscribes, reads
  or writes.
