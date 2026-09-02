/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// The imports below are relative for that reason: a package import would name
// one example or the other and the file could no longer be shared verbatim.
// ignore_for_file: always_use_package_imports

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'panel.dart';
import 'theme.dart';

/// Whether the app may use the radio, in terms both plugins agree on.
///
/// `CentralBluetoothState` and `PeripheralBluetoothState` are the same set of
/// answers under two names. Each example maps its own onto this so the flow
/// below can be written once.
enum AccessState {
  /// Permission is held and the radio is on.
  ready('Ready'),

  /// Permission is held.
  granted('Granted'),

  /// Refused, but it can be asked for again.
  denied('Denied'),

  /// Refused for good. Only the system settings can undo it.
  permanentlyDenied('Permanently denied'),

  /// Permission is held but the radio is off.
  turnedOff('Radio off'),

  /// The hardware cannot do this.
  unsupported('Unsupported'),

  /// Policy on this device forbids it.
  restricted('Restricted'),

  /// Partly granted, which on Apple means scanning without full access.
  limited('Limited'),

  /// Not established yet.
  unknown('Unknown');

  const AccessState(this.label);

  /// The state written for a reader rather than for a switch.
  final String label;

  /// Whether the radio can be used as things stand.
  bool get isUsable => this == ready || this == granted;

  /// How the status rail should light this state.
  SignalGrade get grade => switch (this) {
    ready || granted => SignalGrade.strong,
    limited => SignalGrade.fair,
    turnedOff || denied || unknown => SignalGrade.weak,
    permanentlyDenied || unsupported || restricted => SignalGrade.none,
  };
}

/// What the shell needs from a plugin to get the radio ready.
///
/// The two examples implement this over their own plugin, which is the whole
/// of what the permission flow depends on.
abstract interface class RadioAccess {
  /// Whether this device has the hardware at all.
  Future<bool> get isSupported;

  /// Whether the radio is powered on.
  Future<bool> get isPoweredOn;

  /// The permission held right now, asking the user for nothing.
  Future<AccessState> check();

  /// Asks the user for permission.
  Future<AccessState> request();

  /// Asks the system to power the radio on. Android and Windows only; returns
  /// false where the platform does not allow it.
  Future<bool> powerOn();

  /// Opens this app's page in the system settings.
  Future<void> openAppSettings();

  /// Opens the system's Bluetooth settings.
  Future<void> openRadioSettings();
}

/// Runs the launch-time check: hardware, then permission, then power.
///
/// Each step only appears when it has something to say, so a device that is
/// already set up sees no dialogs at all. Returns the state it ended on.
Future<AccessState> ensureRadioReady(
  BuildContext context,
  RadioAccess access,
) async {
  if (!await access.isSupported) {
    if (context.mounted) await _showUnsupported(context);
    return AccessState.unsupported;
  }

  // Permission comes before power, because Apple reports the adapter as
  // unauthorised rather than as off until the app has been granted access.
  var state = await access.check();
  if (!state.isUsable && context.mounted) {
    state =
        await showDialog<AccessState>(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              _PermissionDialog(access: access, initial: state),
        ) ??
        state;
  }

  if (state.isUsable && !await access.isPoweredOn && context.mounted) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PowerDialog(access: access),
    );
    return access.check();
  }
  return state;
}

Future<void> _showUnsupported(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _InstrumentDialog(
      label: 'NO RADIO',
      grade: SignalGrade.none,
      body: const Text(
        'This device has no Bluetooth Low Energy radio, so there is nothing '
        'for the example to drive.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// The shell's dialog: the same hairline panel as everything else, not a
/// rounded Material card.
class _InstrumentDialog extends StatelessWidget {
  const _InstrumentDialog({
    required this.label,
    required this.grade,
    required this.body,
    required this.actions,
  });

  final String label;
  final SignalGrade grade;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
              StateChip(label: label, grade: grade, pulsing: true),
              DefaultTextStyle.merge(
                style: context.texts.bodyMedium,
                child: body,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Watches for the app coming back to the foreground, since both dialogs send
/// the user to a system settings screen and want to know what they did there.
mixin _RecheckOnResume<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) recheck();
  }

  /// Runs when the app returns to the foreground.
  void recheck();
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({required this.access, required this.initial});

  final RadioAccess access;
  final AccessState initial;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver, _RecheckOnResume {
  late AccessState _state = widget.initial;
  var _asking = false;

  @override
  Future<void> recheck() async {
    final state = await widget.access.check();
    if (!mounted) return;
    if (state.isUsable) {
      Navigator.of(context).pop(state);
    } else {
      setState(() => _state = state);
    }
  }

  Future<void> _ask() async {
    setState(() => _asking = true);
    final state = await widget.access.request();
    if (!mounted) return;
    setState(() {
      _state = state;
      _asking = false;
    });
    if (state.isUsable) Navigator.of(context).pop(state);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _state == AccessState.permanentlyDenied;
    return _InstrumentDialog(
      label: _state.label.toUpperCase(),
      grade: _state.grade,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Text(_explanation),
          if (blocked || _steps.isNotEmpty) StepList(_steps),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_state),
          child: const Text('Not now'),
        ),
        if (blocked)
          FilledButton(
            onPressed: widget.access.openAppSettings,
            child: const Text('Open settings'),
          )
        else
          FilledButton(
            onPressed: _asking ? null : _ask,
            child: Text(_asking ? 'Asking…' : 'Grant access'),
          ),
      ],
    );
  }

  String get _explanation => switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      'Android needs the Bluetooth permissions before the radio will '
          'answer. Below API 31 that includes location, because a radio '
          'scan can be used to infer where you are.',
    TargetPlatform.iOS || TargetPlatform.macOS =>
      'Core Bluetooth reports the adapter as unauthorised, not as off, '
          'until the app has been granted access. Grant it and the real '
          'adapter state appears.',
    TargetPlatform.windows =>
      'Windows needs location access before it will report radio '
          'results, and the device itself has to be discoverable.',
    _ => 'This app needs permission to use the Bluetooth radio.',
  };

  List<String> get _steps {
    if (_state != AccessState.permanentlyDenied) return const [];
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const [
        'Open the app settings.',
        'Go to Permissions, then Nearby devices.',
        'Choose Allow.',
      ],
      TargetPlatform.iOS => const [
        'Open the app settings.',
        'Turn Bluetooth on.',
      ],
      TargetPlatform.macOS => const [
        'Open System Settings, then Privacy & Security.',
        'Choose Bluetooth and turn this app on.',
      ],
      TargetPlatform.windows => const [
        'Open Settings, then Privacy & security.',
        'Choose Location and turn it on.',
      ],
      _ => const [],
    };
  }
}

class _PowerDialog extends StatefulWidget {
  const _PowerDialog({required this.access});

  final RadioAccess access;

  @override
  State<_PowerDialog> createState() => _PowerDialogState();
}

class _PowerDialogState extends State<_PowerDialog>
    with WidgetsBindingObserver, _RecheckOnResume {
  var _working = false;

  /// Android and Windows can be asked to power the radio on. Apple cannot, and
  /// there is no API to open its Bluetooth pane either.
  bool get _canPowerOn =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  Future<void> recheck() async {
    if (await widget.access.isPoweredOn && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _powerOn() async {
    setState(() => _working = true);
    final on = await widget.access.powerOn();
    if (!mounted) return;
    setState(() => _working = false);
    if (on) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _InstrumentDialog(
      label: 'RADIO OFF',
      grade: SignalGrade.weak,
      body: Text(
        _canPowerOn
            ? 'The Bluetooth radio is off. Turn it on and the example picks '
                  'up from where it stopped.'
            : 'The Bluetooth radio is off. Turn it on in the system settings; '
                  'this platform does not let an app do it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        if (_canPowerOn)
          FilledButton(
            onPressed: _working ? null : _powerOn,
            child: Text(_working ? 'Turning on…' : 'Turn on'),
          )
        else
          FilledButton(
            onPressed: widget.access.openRadioSettings,
            child: const Text('Open settings'),
          ),
      ],
    );
  }
}
