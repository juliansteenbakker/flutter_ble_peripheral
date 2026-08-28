/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.

/// A game of pong over the BLE link the rest of the example demonstrates.
///
/// The peripheral hosts: it simulates the ball and both paddles and notifies
/// the state. The central sends its paddle and draws what it is told. Neither
/// half is specific to a plugin, so both repositories carry this verbatim.
library;

export 'court.dart';
export 'engine.dart';
export 'game.dart';
export 'protocol.dart';
export 'scoreboard.dart';
export 'transport.dart';
