/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

/// Model of the data to be advertised.
class AdvertiseData {
  /// Specifies the UUID to be advertised
  String? uuid;

  /// TODO: set to true if transmission power is included.
  bool? transmissionPowerIncluded;

  /// Specifies a manufacturer id
  int? manufacturerId;

  /// ONLY ANDROID: Specifies manufacturer data.
  List<int>? manufacturerData;

  /// Specifies service data UUID
  String? serviceDataUuid;

  /// ONLY ANDROID: Specifies service data
  List<int>? serviceData;

  /// Set to true if device name needs to be included with advertisement
  bool? includeDeviceName;
}
