/*
 * Copyright (c) 2022. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral_example/peripheral_app.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

void main() => runApp(
  const InstrumentApp(
    role: DeviceRole.peripheral,
    home: PeripheralHome(),
  ),
);
