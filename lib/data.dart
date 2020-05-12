/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

class AdvertiseData {
  String uuid;
  bool transmissionPowerIncluded;
  int manufacturerId;
  List<int> manufacturerData;
  String serviceDataUuid;
  List<int> serviceData;
  bool includeDeviceName;
}