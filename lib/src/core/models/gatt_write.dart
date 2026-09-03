/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:typed_data';

/// What a central wrote, and which characteristic it wrote to.
class GattWrite {
  /// Creates a write report.
  const GattWrite({required this.characteristicUuid, required this.data});

  /// The uuid of the characteristic that was written, in the full 128 bit
  /// form, whichever form it was configured with.
  final String characteristicUuid;

  /// The bytes the central wrote.
  final Uint8List data;
}

/// Whether a central is subscribed to one characteristic.
class GattSubscription {
  /// Creates a subscription report.
  const GattSubscription({
    required this.characteristicUuid,
    required this.subscribed,
  });

  /// The uuid of the characteristic, in the full 128 bit form, whichever form
  /// it was configured with.
  final String characteristicUuid;

  /// Whether at least one central is subscribed to it.
  final bool subscribed;
}
