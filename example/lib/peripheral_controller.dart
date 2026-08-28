/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

/// The service the flutter_ble_central example looks for.
const exampleServiceUuid = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';

/// The name advertised with it, which is what shows up in a scanner.
const exampleLocalName = 'Flutter BLE';

/// Something worth telling the user about, shown as a snack bar.
typedef Notice = ({String message, bool isError});

/// One payload that crossed the link.
typedef Packet = ({Uint8List bytes, PacketDirection direction, DateTime at});

/// Drives `FlutterBlePeripheral` and holds everything the pages read.
///
/// The mirror of `CentralController` in the flutter_ble_central example: the
/// pages are widgets over this, and every plugin call goes through [_call] so
/// a platform that does not serve one says so.
final class PeripheralController extends ChangeNotifier implements RadioAccess {
  /// Creates a controller and starts listening to the plugin's streams.
  PeripheralController() {
    _subscriptions.addAll([
      _ble.onDataReceived.listen(_onDataReceived),
      _ble.onMtuChanged.listen(_onMtuChanged),
      _ble.onSubscriptionChanged.listen(_onSubscriptionChanged),
      ?_ble.onPeripheralStateChanged?.listen(_onPeripheralState),
    ]);
  }

  final _ble = FlutterBlePeripheral();
  final _subscriptions = <StreamSubscription<void>>[];

  /// What the status rail plots.
  final telemetry = LinkTelemetry();

  /// The most recent thing worth saying. The app shows it and clears it.
  final notice = ValueNotifier<Notice?>(null);

  // What gets advertised ----------------------------------------------------

  /// The uuid of the advertised service, which is also the GATT service.
  String serviceUuid = exampleServiceUuid;

  /// The name broadcast alongside it.
  String localName = exampleLocalName;

  /// The manufacturer identifier, or null to advertise none.
  int? manufacturerId = 1234;

  /// The manufacturer payload, or null to advertise none.
  Uint8List? manufacturerData = Uint8List.fromList([
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
  ]);

  /// How hard Android advertises, traded against battery.
  AdvertiseMode advertiseMode = AdvertiseMode.advertiseModeLowLatency;

  /// How loudly Android advertises.
  AdvertiseTxPower txPower = AdvertiseTxPower.advertiseTxPowerHigh;

  /// How long to advertise for, in milliseconds. Zero means indefinitely.
  int timeout = 0;

  /// Whether a central may connect. A GATT server is pointless without it.
  bool connectable = true;

  /// Whether Apple should also advertise the service in its overflow area,
  /// which is what lets a backgrounded app stay discoverable to other Apple
  /// devices.
  bool useOverflowArea = false;

  /// Whether Windows should use an extended advertisement, which carries more
  /// than the legacy 31 bytes.
  bool useExtendedAdvertisement = false;

  /// Replaces one setting and tells the pages.
  void update(void Function() change) {
    change();
    notifyListeners();
  }

  // What the radio is doing -------------------------------------------------

  /// The peripheral's own state machine.
  PeripheralState get state => _state;
  PeripheralState _state = PeripheralState.unknown;

  /// Whether the advertisement is on the air.
  bool get isAdvertising => _state == PeripheralState.advertising;

  /// Whether a central has subscribed to the TX characteristic.
  ///
  /// `sendData` throws until this is true: a peripheral cannot notify a
  /// central that never asked to be notified.
  bool get isSubscribed => _isSubscribed;
  bool _isSubscribed = false;

  /// The MTU the link negotiated, once a central has connected.
  int? get mtu => _mtu;
  int? _mtu;

  /// What has crossed the link, newest first.
  List<Packet> get traffic => List.unmodifiable(_traffic);
  final _traffic = <Packet>[];

  /// Called for every payload a central writes, so the game can read the link
  /// without the Data page being open.
  void Function(Uint8List bytes)? onInbound;

  /// Whether a game is running over the link.
  ///
  /// A game sends twenty packets a second in each direction. While this is set
  /// they are counted on the meter and nothing else, so the traffic log does
  /// not fill with paddle positions.
  bool isGameRunning = false;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    telemetry.dispose();
    notice.dispose();
    super.dispose();
  }

  // Streams -----------------------------------------------------------------

  void _onDataReceived(Uint8List bytes) {
    telemetry.count(PacketDirection.inbound);
    onInbound?.call(bytes);
    if (isGameRunning) return;
    _record(bytes, PacketDirection.inbound);
    notifyListeners();
  }

  void _onMtuChanged(int mtu) {
    _mtu = mtu;
    _reportLink();
    notifyListeners();
  }

  void _onSubscriptionChanged(bool subscribed) {
    _isSubscribed = subscribed;
    _say(subscribed ? 'A central subscribed' : 'The central unsubscribed');
    _reportLink();
    notifyListeners();
  }

  void _onPeripheralState(PeripheralState state) {
    _state = state;
    _reportLink();
    notifyListeners();
  }

  // Doing things ------------------------------------------------------------

  /// Starts advertising and opens the GATT server.
  Future<void> startAdvertising() async {
    try {
      final state = await _ble.start(
        advertiseData: AndroidAdvertiseData(
          serviceUuid: serviceUuid,
          localName: localName.isEmpty ? null : localName,
          manufacturerId: manufacturerId,
          manufacturerData: manufacturerData,
        ),
        // Serving the TX/RX pair is what makes this more than a beacon; the
        // characteristic uuids default to the Nordic UART Service ones.
        gattServer: const GattServerSettings(),
        androidSettings: AndroidAdvertiseSettings(
          advertiseSettings: AdvertiseSettings(
            advertiseMode: advertiseMode,
            txPowerLevel: txPower,
            timeout: timeout,
            connectable: connectable,
          ),
        ),
        darwinSettings: DarwinAdvertiseSettings(
          overflowServiceUuids: useOverflowArea ? [serviceUuid] : null,
        ),
        windowsSettings: WindowsAdvertiseSettings(
          timeout: timeout,
          useExtendedAdvertisement: useExtendedAdvertisement,
        ),
      );
      if (!state.access.isUsable) {
        _say('Cannot advertise: ${state.access.label}', isError: true);
        return;
      }
      _say('Advertising $localName');
    } on PlatformException catch (error) {
      _say('Advertising failed: ${error.message}', isError: true);
    }
    await refreshState();
  }

  /// Stops advertising, which also closes the GATT server.
  Future<void> stopAdvertising() async {
    await _ble.stop();
    _isSubscribed = false;
    _mtu = null;
    _traffic.clear();
    telemetry.clear();
    await refreshState();
  }

  /// Notifies every subscribed central with [bytes].
  Future<bool> sendData(Uint8List bytes) async {
    if (!_isSubscribed) {
      _say(
        'No central is subscribed, so there is nobody to notify.',
        isError: true,
      );
      return false;
    }
    try {
      await _ble.sendData(bytes);
      telemetry.count(PacketDirection.outbound);
      if (!isGameRunning) {
        _record(bytes, PacketDirection.outbound);
        notifyListeners();
      }
      return true;
    } on PlatformException catch (error) {
      _say('Send failed: ${error.message}', isError: true);
      return false;
    }
  }

  /// Asks the platform where things stand rather than trusting the stream.
  Future<void> refreshState() async {
    if (await _ble.isAdvertising) {
      _state = PeripheralState.advertising;
    } else if (_state == PeripheralState.advertising) {
      _state = PeripheralState.idle;
    }
    _isSubscribed = await _ble.isSubscribed;
    _reportLink();
    notifyListeners();
  }

  /// Reports whether a central is connected.
  Future<void> readIsConnected() => _call('Connected', () async {
    final connected = await _ble.isConnected;
    return connected ? 'yes' : 'no';
  });

  /// Reports whether a central has subscribed to TX.
  Future<void> readIsSubscribed() => _call('Subscribed', () async {
    _isSubscribed = await _ble.isSubscribed;
    return _isSubscribed ? 'yes' : 'no';
  });

  /// Reports whether the advertisement is on the air.
  Future<void> readIsAdvertising() => _call('Advertising', () async {
    final advertising = await _ble.isAdvertising;
    return advertising ? 'yes' : 'no';
  });

  /// Whether Windows Nearby Sharing is on, which competes for the radio.
  Future<void> readNearbyShare() => _call('Nearby Sharing', () async {
    final enabled = await _ble.isNearbyShareEnabled();
    return enabled ? 'on, which can block advertising' : 'off';
  });

  /// Opens the Windows sharing settings.
  Future<void> openNearbyShareSettings() => _ble.openNearbyShareSettings();

  /// Opens the Windows location settings, which BLE needs there.
  Future<void> openLocationSettings() => _ble.openLocationSettings();

  /// Runs a plugin call and says what it did.
  Future<void> _call(String label, Future<String> Function() body) async {
    try {
      _say('$label: ${await body()}');
    } on PlatformException catch (error) {
      _say(
        error.code == 'unsupported'
            ? '$label is not supported on this platform'
            : '$label failed: ${error.message}',
        isError: true,
      );
    }
    notifyListeners();
  }

  // Housekeeping ------------------------------------------------------------

  void _record(Uint8List bytes, PacketDirection direction) {
    _traffic.insert(
      0,
      (bytes: bytes, direction: direction, at: DateTime.now()),
    );
    if (_traffic.length > 50) _traffic.removeLast();
  }

  /// A peripheral has no RSSI to plot: it never scans, so it never measures
  /// anyone. The trace is how far along the handshake the link is instead.
  void _reportLink() {
    final (grade, caption, level) = switch (this) {
      _ when _isSubscribed => (
        SignalGrade.strong,
        _mtu == null ? 'subscribed' : 'subscribed, MTU $_mtu',
        1.0,
      ),
      _ when isAdvertising => (SignalGrade.fair, 'advertising', 0.45),
      _ => (SignalGrade.none, 'idle', 0.0),
    };
    telemetry.report(grade: grade, caption: caption, level: level);
  }

  void _say(String message, {bool isError = false}) {
    notice.value = (message: message, isError: isError);
  }

  // RadioAccess -------------------------------------------------------------

  @override
  Future<bool> get isSupported => _ble.isSupported;

  @override
  Future<bool> get isPoweredOn => _ble.isBluetoothOn;

  @override
  Future<AccessState> check() async => (await _ble.hasPermission()).access;

  @override
  Future<AccessState> request() async =>
      (await _ble.requestPermission()).access;

  @override
  Future<bool> powerOn() => _ble.enableBluetooth();

  @override
  Future<void> openAppSettings() => _ble.openAppSettings();

  @override
  Future<void> openRadioSettings() => _ble.openBluetoothSettings();
}

/// Maps the plugin's answer onto the one the shell speaks.
extension on PeripheralBluetoothState {
  AccessState get access => switch (this) {
    PeripheralBluetoothState.ready => AccessState.ready,
    PeripheralBluetoothState.granted => AccessState.granted,
    PeripheralBluetoothState.denied => AccessState.denied,
    PeripheralBluetoothState.permanentlyDenied => AccessState.permanentlyDenied,
    PeripheralBluetoothState.turnedOff => AccessState.turnedOff,
    PeripheralBluetoothState.unsupported => AccessState.unsupported,
    PeripheralBluetoothState.restricted => AccessState.restricted,
    PeripheralBluetoothState.limited => AccessState.limited,
    PeripheralBluetoothState.unknown => AccessState.unknown,
  };
}

/// How healthy each peripheral state is, on the shell's one ramp.
extension PeripheralStateGrade on PeripheralState {
  /// The grade the status rail lights this state in.
  SignalGrade get grade => switch (this) {
    PeripheralState.advertising ||
    PeripheralState.connected => SignalGrade.strong,
    PeripheralState.idle => SignalGrade.fair,
    PeripheralState.poweredOff ||
    PeripheralState.locationServicesDisabled ||
    PeripheralState.unknown => SignalGrade.weak,
    PeripheralState.unauthorized ||
    PeripheralState.shouldShowRequestPermissionRationale ||
    PeripheralState.unsupported => SignalGrade.none,
  };
}
