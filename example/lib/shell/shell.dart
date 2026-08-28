/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.

/// The instrument shell the two example apps are built from.
///
/// Both apps are the same face with one hue swapped, so everything here is
/// written once and copied into the other repository verbatim.
library;

export 'access.dart';
export 'hex.dart';
export 'instrument_app.dart';
export 'link_meter.dart';
export 'panel.dart';
export 'theme.dart';
