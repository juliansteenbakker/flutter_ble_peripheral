import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advertise_set_parameters.g.dart';

/// Extended advertising parameters for Android 8+ (API level 26).
///
/// Maps to `AdvertisingSetParameters.Builder` in Android native code.
///
/// Extended advertising provides advanced features over legacy advertising:
/// - Larger data payloads (up to 1650 bytes vs 31 bytes)
/// - Multiple concurrent advertisements
/// - 2M PHY for higher throughput
/// - Coded PHY for longer range (up to 4x)
/// - Periodic advertising
/// - Extended connectable/scannable modes
///
/// ## Usage
///
/// Use [AdvertiseSetParameters] when you need:
/// - Android 8+ features (extended advertising, PHY options, periodic
///   advertising)
/// - More than 31 bytes of advertising data
/// - Long-range or high-throughput communication
///
/// For Android 7 and below, or simple use cases, use [AdvertiseSettings]
/// instead.
///
/// ## Example
///
/// ```dart advertiseSetParameters: AdvertiseSetParameters( connectable: true,
/// interval: intervalMedium, txPowerLevel: txPowerHigh, primaryPhy: phy1m,
/// secondaryPhy: phy2m, legacyMode: false, ) ```
///
/// Reference:
/// https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetParameters
///
/// Requires Android 8.0 (API level 26) or higher.
@JsonSerializable()
class AdvertiseSetParameters {
  /// Creates the parameters for an advertising set.
  const AdvertiseSetParameters({
    this.connectable = false,
    this.txPowerLevel = txPowerHigh,
    this.interval = intervalHigh,
    this.legacyMode = false,
    this.primaryPhy,
    this.scannable,
    this.secondaryPhy,
    this.anonymous,
    this.includeTxPowerLevel = false,
    this.duration,
    this.maxExtendedAdvertisingEvents,
  });

  /// Creates parameters from the map [toJson] produces.
  factory AdvertiseSetParameters.fromJson(Map<String, dynamic> json) =>
      _$AdvertiseSetParametersFromJson(json);

  /// Set whether the device address is anonymous (non-resolvable).
  ///
  /// When enabled, the advertising address changes frequently and cannot be
  /// traced back to a specific device.
  ///
  /// Default: null (uses system default)
  ///
  /// Android API: `AdvertisingSetParameters.Builder.setAnonymous(anonymous)`
  final bool? anonymous;

  /// Set whether the advertisement type should be connectable or
  /// non-connectable.
  ///
  /// - `true`: Other devices can connect to establish a GATT connection
  /// - `false`: Broadcast-only mode, saves power
  ///
  /// Default: false
  ///
  /// Android API:
  /// `AdvertisingSetParameters.Builder.setConnectable(connectable)`
  final bool connectable;

  /// Whether the transmission power level should be included in the
  /// advertisement.
  ///
  /// Including TX power helps receivers estimate distance to the advertiser.
  /// Reduces available space for other advertising data.
  ///
  /// Default: false
  ///
  /// Android API:
  /// `AdvertisingSetParameters.Builder.setIncludeTxPower(includeTxPowerLevel)`
  final bool? includeTxPowerLevel;

  /// Advertising interval in units of 0.625ms slots.
  ///
  /// Valid range: 160 to 16777215 (100ms to ~2.9 hours)
  ///
  /// Common values (from `constants.dart`):
  /// - [intervalMin]/[intervalLow]: 160 (100ms) - Frequent, quick discovery
  /// - [intervalMedium]: 400 (250ms) - Balanced
  /// - [intervalHigh]: 1600 (1 second) - Power efficient
  ///
  /// Lower values = faster discovery but higher battery usage.
  ///
  /// Default: [intervalHigh] (1600)
  ///
  /// Android API: `AdvertisingSetParameters.Builder.setInterval(interval)`
  final int interval;

  /// Set whether legacy advertising mode should be used.
  ///
  /// - `true`: Use legacy PDU format (compatible with pre-Bluetooth 5 devices)
  /// - `false`: Use extended PDU format (Bluetooth 5+ features, larger
  ///   payloads)
  ///
  /// When true:
  /// - Maximum 31 bytes of advertising data
  /// - Compatible with all BLE devices
  /// - Cannot use 2M or Coded PHY
  ///
  /// When false:
  /// - Up to 1650 bytes of advertising data
  /// - Requires Bluetooth 5.0+ scanner
  /// - Can use 2M PHY and Coded PHY
  ///
  /// Default: false (use extended advertising)
  ///
  /// Android API: `AdvertisingSetParameters.Builder.setLegacyMode(legacyMode)`
  final bool legacyMode;

  /// Primary advertising PHY (Physical Layer).
  ///
  /// The primary channel is used for initial advertising packets.
  ///
  /// Valid values (from `constants.dart`):
  /// - [phy1m] (1): Standard 1 Mbit/s, maximum compatibility
  /// - [phyCoded] (3): Long range mode, up to 4x range
  ///
  /// Note: [phy2m] is NOT valid for primary PHY.
  ///
  /// Default: null (uses system default, typically [phy1m])
  ///
  /// Android API: `AdvertisingSetParameters.Builder.setPrimaryPhy(primaryPhy)`
  final int? primaryPhy;

  /// Set whether the advertisement should be scannable.
  ///
  /// Scannable advertisements allow devices to request additional data via a
  /// scan response.
  ///
  /// - `true`: Supports scan response (can send more data)
  /// - `false`: No scan response support
  ///
  /// Default: null (uses system default based on other parameters)
  ///
  /// Android API: `AdvertisingSetParameters.Builder.setScannable(scannable)`
  final bool? scannable;

  /// Secondary advertising PHY (Physical Layer).
  ///
  /// The secondary channel is used for auxiliary advertising packets when using
  /// extended advertising (legacyMode = false).
  ///
  /// Valid values (from `constants.dart`):
  /// - [phy1m] (1): Standard 1 Mbit/s
  /// - [phy2m] (2): High throughput 2 Mbit/s
  /// - [phyCoded] (3): Long range mode
  ///
  /// Ignored when [legacyMode] is true.
  ///
  /// Default: null (uses system default)
  ///
  /// Android API:
  /// `AdvertisingSetParameters.Builder.setSecondaryPhy(secondaryPhy)`
  final int? secondaryPhy;

  /// TX (transmission) power level in dBm.
  ///
  /// Controls the transmission power level for advertising packets. Higher
  /// values = longer range but more battery consumption.
  ///
  /// Valid values (from `constants.dart`):
  /// - [txPowerMax]/[txPowerHigh]: 1 dBm - Maximum range
  /// - [txPowerMedium]: -7 dBm - Balanced
  /// - [txPowerLow]: -15 dBm - Reduced range, better battery
  /// - [txPowerUltraLow]: -21 dBm - Very short range
  /// - [txPowerMin]: -127 dBm - Minimum range
  ///
  /// Default: [txPowerHigh] (1)
  ///
  /// Android API:
  /// `AdvertisingSetParameters.Builder.setTxPowerLevel(txPowerLevel)`
  final int txPowerLevel;

  /// Advertising duration in milliseconds (10ms units).
  ///
  /// Maximum duration for this advertising set. Advertising will automatically
  /// stop after this time.
  ///
  /// - `0`: No timeout (advertise indefinitely)
  /// - `> 0`: Stop after specified duration
  ///
  /// Default: null (no timeout)
  ///
  /// Android API: Part of `startAdvertisingSet()` call
  final int? duration;

  /// Maximum number of extended advertising events.
  ///
  /// Advertising will automatically stop after this many advertising events.
  ///
  /// - `0`: No limit
  /// - `> 0`: Stop after specified number of events
  ///
  /// Default: null (no limit)
  ///
  /// Android API: Part of `startAdvertisingSet()` call
  final int? maxExtendedAdvertisingEvents;

  /// The map sent over the method channel to the platform.
  Map<String, dynamic> toJson() => _$AdvertiseSetParametersToJson(this);
}
