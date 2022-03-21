/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

enum AdvertiseTxPower {
  /// Advertise using the lowest transmission (TX) power level. Low transmission power can be used
  /// to restrict the visibility range of advertising packets.
  advertiseTxPowerUltraLow,

  /// Advertise using low TX power level.
  advertiseTxPowerLow,

  /// Advertise using medium TX power level.
  advertiseTxPowerMedium,

  /// Advertise using high TX power level. This corresponds to largest visibility range of the
  /// advertising packet.
  advertiseTxPowerHigh
}