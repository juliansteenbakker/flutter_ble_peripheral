/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

/// Advertising intervals and TX power levels for `AdvertiseSetParameters`,
/// mirroring the constants on Android's `AdvertisingSetParameters`.
///
/// Intervals are counted in units of 0.625 ms, so 160 is every 100 ms.
/// A shorter interval is discovered faster but costs more power.
library;

/// Advertise every 100 ms. The most responsive of the presets, and the
/// most power hungry.
const int intervalLow = 160;

/// Advertise every second. The least power hungry of the presets, and the
/// slowest to be discovered.
const int intervalHigh = 1600;

/// The longest interval the platform accepts.
const int intervalMax = 16777215;

/// Advertise every 250 ms.
const int intervalMedium = 400;

/// The shortest interval the platform accepts, equal to [intervalLow].
const int intervalMin = 160;

/// Transmit at 1 dBm, the strongest of the presets. Gives the longest range.
const int txPowerHigh = 1;

/// Transmit at -15 dBm.
const int txPowerLow = -15;

/// The strongest power the platform accepts, equal to [txPowerHigh].
const int txPowerMax = 1;

/// Transmit at -7 dBm.
const int txPowerMedium = -7;

/// The weakest power the platform accepts. Effectively disables advertising
/// beyond a few centimetres.
const int txPowerMin = -127;

/// Transmit at -21 dBm, for advertising only to devices held very close.
const int txPowerUltraLow = -21;
