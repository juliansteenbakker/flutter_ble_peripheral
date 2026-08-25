/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// ========== Advertising Interval Constants ==========
//
// Used with [AdvertiseSetParameters.interval]
// Unit: 0.625 millisecond slots
//
// Android API: AdvertisingSetParameters.Builder.setInterval(interval)

/// Minimum advertising interval: 160 slots (100ms)
///
/// Provides frequent advertising for quick device discovery.
const int intervalMin = 160;

/// Low advertising interval: 160 slots (100ms)
///
/// Same as minimum, provides maximum visibility.
const int intervalLow = 160;

/// Medium advertising interval: 400 slots (250ms)
///
/// Balanced between power consumption and discovery time.
const int intervalMedium = 400;

/// High advertising interval: 1600 slots (1 second)
///
/// Reduced power consumption, slower discovery.
const int intervalHigh = 1600;

/// Maximum advertising interval: 16777215 slots (~2.9 hours)
///
/// Absolute maximum supported by the specification.
const int intervalMax = 16777215;

// ========== TX Power Level Constants ==========
//
// Used with [AdvertiseSetParameters.txPowerLevel]
// Unit: dBm (decibels relative to one milliwatt)
//
// Android API: AdvertisingSetParameters.Builder.setTxPowerLevel(txPowerLevel)

/// Maximum TX power level: 1 dBm
///
/// Highest transmission power, maximum range, highest battery consumption.
const int txPowerMax = 1;

/// High TX power level: 1 dBm
///
/// Same as maximum, provides longest range.
const int txPowerHigh = 1;

/// Medium TX power level: -7 dBm
///
/// Balanced power consumption and range.
const int txPowerMedium = -7;

/// Low TX power level: -15 dBm
///
/// Reduced range, better battery life.
const int txPowerLow = -15;

/// Ultra low TX power level: -21 dBm
///
/// Very short range, best battery life.
const int txPowerUltraLow = -21;

/// Minimum TX power level: -127 dBm
///
/// Absolute minimum, extremely short range.
const int txPowerMin = -127;

// ========== PHY (Physical Layer) Constants ==========
//
// Used with AdvertiseSetParameters.primaryPhy and
// AdvertiseSetParameters.secondaryPhy
//
// Android API: BluetoothDevice.PHY_LE_*

/// Bluetooth LE 1M PHY
///
/// Standard 1 Mbit/s data rate, compatible with all BLE devices. Use for
/// maximum compatibility.
///
/// Android API: BluetoothDevice.PHY_LE_1M
const int phy1m = 1;

/// Bluetooth LE 2M PHY
///
/// 2 Mbit/s data rate, available on Bluetooth 5.0+ devices. Higher throughput
/// but shorter range than 1M.
///
/// Android API: BluetoothDevice.PHY_LE_2M
const int phy2m = 2;

/// Bluetooth LE Coded PHY
///
/// Long range mode with error correction, available on Bluetooth 5.0+ devices.
/// Slower data rate (125 or 500 kbit/s) but up to 4x range compared to 1M.
///
/// Android API: BluetoothDevice.PHY_LE_CODED
const int phyCoded = 3;
