/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

/// What a central may do with a characteristic the peripheral serves.
enum GattCharacteristicProperty {
  /// A central may read the value, which is the payload sent last.
  read(1),

  /// A central may write, and is answered.
  write(2),

  /// A central may write without waiting for an answer.
  writeWithoutResponse(4),

  /// The peripheral may notify subscribed centrals of a new value.
  notify(8),

  /// As [notify], but each notification is acknowledged by the central.
  indicate(16);

  const GattCharacteristicProperty(this.bit);

  /// The value this property crosses the platform channel as.
  ///
  /// Chosen by this package rather than taken from any one platform's
  /// constants, so that all three decode the same numbers and none of them is
  /// silently right by accident.
  final int bit;
}
