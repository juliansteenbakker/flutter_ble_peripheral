/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

/// Model of the data to be advertised.
class AdvertiseData {

  /// Set an uuid to be advertised. example: bf27730d-860a-4e09-889c-2d8b6a9e0fe7
  String? uuid;

  /// Set to true if transmission power is included
  /// TODO: The transmission power itself has yet to be passed through
  bool? transmissionPowerIncluded;

  /// Set the manufacturer id.
  int? manufacturerId;

  /// Set manufacturer specific data.
  List<int>? manufacturerData;

  /// Set service data UUID.
  /// See https://btprodspecificationrefs.blob.core.windows.net/assigned-values/16-bit%20UUID%20Numbers%20Document.pdf
  String? serviceDataUuid;

  /// Set service data
  List<int>? serviceData;

  /// Set to true to include device name
  bool? includeDeviceName;
}
