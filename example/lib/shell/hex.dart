/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.

import 'dart:typed_data';

/// Reads the hex bytes a user typed, such as `01 02 03` or `01,02,03`.
///
/// Returns null when the field is empty or holds something that is not a byte,
/// so the caller can say so rather than send nonsense over the air.
Uint8List? parseHexBytes(String input) {
  final fields = input
      .split(RegExp('[^0-9a-fA-F]+'))
      .where((s) => s.isNotEmpty);
  if (fields.isEmpty) return null;

  final bytes = <int>[];
  for (final field in fields) {
    final value = int.tryParse(field, radix: 16);
    if (value == null || value > 0xFF) return null;
    bytes.add(value);
  }
  return Uint8List.fromList(bytes);
}

/// Writes [bytes] the way the fields expect them back: lowercase pairs,
/// space separated.
String formatHexBytes(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

/// Shortens a uuid to its first and last group, for the rows too narrow to
/// carry all 36 characters.
///
/// A full uuid still belongs in a readout that has room for it; this is for
/// list rows and chips.
String shortUuid(String uuid) {
  final groups = uuid.split('-');
  if (groups.length != 5) return uuid;
  return '${groups.first}…${groups.last}';
}
