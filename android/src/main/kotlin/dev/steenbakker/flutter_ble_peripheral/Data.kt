/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

package dev.steenbakker.flutter_ble_peripheral

import android.bluetooth.le.AdvertiseSettings

class Data(
        var uuid: String = "",
        var manufacturerId: Int? = null,
        var manufacturerData: List<Int> = mutableListOf(),
        var serviceDataUuid: String = "8ebdb2f3-7817-45c9-95c5-c5e9031aaa47",
        var serviceData: List<Int> = mutableListOf(),
        var txCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D4",
        var rxCharacteristicUUID: String = "08590F7E-DB05-467E-8757-72F6FAEB13D5",
        var includeDeviceName: Boolean = false,
        var includeTxPowerLevel: Boolean = false,
        var advertiseMode: Int = AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY,
        var connectable: Boolean = false,
        var timeout: Int = 400,
        var txPowerLevel: Int = AdvertiseSettings.ADVERTISE_TX_POWER_HIGH
)
