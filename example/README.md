# Flutter BLE Peripheral Example

Advertises this device as a BLE peripheral, serves a GATT service with a TX/RX
characteristic pair, and hosts a game of pong over the link.

It is the peripheral half of a pair. The other half is the example in
[flutter_ble_central](https://github.com/juliansteenbakker/flutter_ble_central);
see [Running the pair](#running-the-pair) below. The two apps are the same
instrument with one hue swapped — this one is red, the central is cobalt — so a
pair of devices on a desk can be told apart at a glance.

## The four pages

| | What it is for |
| --- | --- |
| **Link** | Go on the air, and see what is connected |
| **Data** | Exchange bytes with a connected central |
| **Pong** | A game over the link, on one device or two |
| **Setup** | Broadcast settings, permissions and the adapter |

Across the top is a status rail that never scrolls: which half of the link this
app is, what the radio is doing, and a live meter. A peripheral never scans, so
it has no RSSI to plot; the trace shows how far along the handshake the link is
instead — off air, on air, subscribed. Every notification and every write raises
a tick along its top edge, so the strip is the ATT traffic rather than a
decoration of it.

## Using it

1. **Setup** — the app runs the access check on launch, and the Permissions
   panel can run it again. Android needs the Bluetooth permissions; Windows
   needs location.
2. **Link** — press Start advertising. The radio goes on the air and the GATT
   server opens with it.
3. **Connect** — the state chip turns to `subscribed` once a central subscribes
   to TX.
4. **Data** — enter hex bytes such as `01 02 03` and press Notify on TX. The
   button stays off until a central has subscribed, because a peripheral cannot
   notify one that never asked to be notified. Anything a central writes to RX
   appears in the log below.

## What it advertises

| | Default | Where |
| --- | --- | --- |
| Service UUID | `bf27730d-860a-4e09-889c-2d8b6a9e0fe7` | Link page, configurable |
| Local name | `Flutter BLE` | Link page, configurable |
| Manufacturer ID and data | `1234`, `01 02 03 04 05 06` | Link page, configurable |
| TX characteristic | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` | `defaultTxCharacteristicUuid` |
| RX characteristic | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` | `defaultRxCharacteristicUuid` |

TX supports read, notify and indicate, and carries what the peripheral sends. RX
supports write and write-without-response, and carries what the central sends.
Both default to the Nordic UART Service characteristics, so a central that knows
that profile finds them without being told the uuids out of band. Pass your own
to `GattServerSettings` to serve a different layout.

The Setup page carries how it is broadcast rather than what: advertise mode and
TX power on Android, the overflow area on Apple, extended advertisements on
Windows, and whether the advertisement is connectable at all. Each row says
which platforms read it. Both pages lock while advertising is running, since the
advertisement is built when the radio starts.

## Pong

The Pong page plays a real game over the GATT link the rest of the app
demonstrates.

**One device** needs no radio and no second phone. A host and a guest run in the
same process, wired to each other through a loopback that encodes, delays and
decodes every message exactly as the radio would. Both paddles play themselves.

**Two devices** is the real thing. This end hosts, because it is the end a
central connects to: it simulates the ball and both paddles, and notifies the
state on TX twenty times a second. The central sends only its paddle position,
as a write on RX, and draws what it is told — so the two ends cannot disagree
about the score however bad the link gets. Drag anywhere across the court to
move your paddle. If the central goes quiet mid-game its paddle is picked up by
an automatic player rather than the rally freezing.

Every message fits in 20 bytes, which is what an unnegotiated ATT MTU carries,
so a game works without asking for anything. The host paces itself by awaiting
each `sendData` rather than by a timer: `sendData` queues per central, and a
fixed-rate timer against a slower link would grow that queue without bound. The
state that gets dropped is always the older one, which is the right trade — a
stale ball position is worth nothing.

`flutter test` covers the wire format and the physics; neither needs a radio.

## Running the pair

You need two devices; a phone and a Mac both work, and BLE does not work in a
simulator.

1. Run this example on the first device and press Start advertising.
2. Run the `flutter_ble_central` example on the second device and press Start
   scan.
3. On the central, tap `Flutter BLE`. It connects, discovers the service and
   subscribes to TX.
4. Here, the state chip turns to `subscribed` and the Notify button becomes
   enabled.
5. Send bytes from either side on the Data page, or open Pong on both and play.

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
| Windows | yes | yes |

## Notes

- Stopping advertising closes the GATT server and drops any queued payloads.
- `sendData` queues per central, so back-to-back calls arrive in order rather
  than overwriting each other. It throws when no central is subscribed, rather
  than dropping the payload.
- A central that reads TX gets the payload sent last, so one that subscribes
  late can still pick it up.
- Several centrals can connect at once. The example is written around a single
  one, but `sendData` notifies every subscriber.
- Only Android answers `isConnected` exactly. On iOS and macOS a central becomes
  visible once it subscribes, reads or writes, since CoreBluetooth never reports
  a bare connection; on Windows it is the same answer as `isSubscribed`.
- Windows advertises the service through the GATT service provider rather than
  the advertisement publisher, which is also what makes it connectable there.
  It also shares one radio with Nearby Sharing, and the two fight — the Setup
  page has a check for it.

## Shared with flutter_ble_central

`lib/shell/` and `lib/pong/` are byte-identical in both repositories, along with
`test/pong_test.dart` and the bundled fonts. An example cannot depend on a
package that is not on pub, and a path dependency on a sibling repository breaks
for anyone who clones only one, so the files are copied instead. The comparison
tool lives in flutter_ble_central, which is the copy of record:

```sh
cd ../flutter_ble_central
dart run tool/sync_example_shell.dart          # report drift
dart run tool/sync_example_shell.dart --write  # copy that repository's over
```

CI in both repositories runs the first form, so the copies cannot quietly
diverge. Make changes in flutter_ble_central and copy them here.

## Fonts

Archivo and IBM Plex Mono, both under the SIL Open Font License, bundled in
`assets/fonts/` with their licences. Archivo ships as a single variable file
and is used at two widths: normal for text, and its widest for the stencilled
panel labels.
