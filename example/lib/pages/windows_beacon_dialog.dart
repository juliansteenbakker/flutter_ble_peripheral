/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

/// What the user chose in [showWindowsBeaconDialog].
enum BeaconChoice {
  /// Turn off the sharing features, then advertise.
  turnOff,

  /// Advertise with them left on.
  advertiseAnyway,

  /// Go to Settings instead of advertising.
  openSettings,
}

/// Warns that Windows sharing features will take turns with the advertisement
/// on this adapter, and asks what to do about it.
///
/// Peripheral only, so it lives here rather than in the shell shared with the
/// central example. It wears the shell's dialog look all the same.
Future<BeaconChoice?> showWindowsBeaconDialog(
  BuildContext context, {
  required bool shareAcrossDevices,
  required bool nearbyShare,
}) {
  final features = [
    if (shareAcrossDevices) 'Share across devices',
    if (nearbyShare) 'Nearby sharing',
  ].join(' and ');
  return showDialog<BeaconChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _BeaconDialog(
      body: Text(
        '$features ${features.contains(' and ') ? 'make' : 'makes'} Windows '
        'broadcast a beacon of its own. This Bluetooth adapter has room for '
        'one advertisement at a time, so the beacon takes turns with this '
        "app's, which is then on air for about one second in six. Scanners "
        'will rarely see it.',
      ),
    ),
  );
}

class _BeaconDialog extends StatelessWidget {
  const _BeaconDialog({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    void choose(BeaconChoice choice) => Navigator.of(context).pop(choice);
    return Dialog(
      backgroundColor: tokens.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.hairline),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              const StateChip(
                label: 'SHARED RADIO',
                grade: SignalGrade.fair,
                pulsing: true,
              ),
              DefaultTextStyle.merge(
                style: context.texts.bodyMedium,
                child: body,
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => choose(BeaconChoice.openSettings),
                    child: const Text('Open settings'),
                  ),
                  OutlinedButton(
                    onPressed: () => choose(BeaconChoice.advertiseAnyway),
                    child: const Text('Advertise anyway'),
                  ),
                  FilledButton(
                    onPressed: () => choose(BeaconChoice.turnOff),
                    child: const Text('Turn off'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
