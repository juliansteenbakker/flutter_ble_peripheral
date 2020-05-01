/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

class Data(
        val uuid: String,
        val transmissionPowerIncluded: Boolean?,
        val manufacturerId: Int?,
        val manufacturerData: List<Int>?,
        val serviceDataUuid: String?,
        val serviceData: List<Int>?,
        val includeDeviceName: Boolean?
)