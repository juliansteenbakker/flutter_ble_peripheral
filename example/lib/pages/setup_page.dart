/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_ble_peripheral_example/peripheral_controller.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

/// Permissions, the adapter, and how the advertisement is broadcast.
class SetupPage extends StatelessWidget {
  /// Creates the page over [controller].
  const SetupPage({required this.controller, super.key});

  /// The one controller the app runs on.
  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _AdvertiseSettingsPanel(controller: controller),
        const SizedBox(height: 12),
        _PermissionPanel(controller: controller),
        const SizedBox(height: 12),
        _AdapterPanel(controller: controller),
        if (defaultTargetPlatform == TargetPlatform.windows) ...[
          const SizedBox(height: 12),
          _WindowsPanel(controller: controller),
        ],
      ],
    );
  }
}

/// How the radio broadcasts, as opposed to what it broadcasts.
class _AdvertiseSettingsPanel extends StatelessWidget {
  const _AdvertiseSettingsPanel({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    final locked = controller.isAdvertising;
    final android = defaultTargetPlatform == TargetPlatform.android;

    return Panel(
      label: 'BROADCAST',
      footnote: locked
          ? 'Stop advertising to change these.'
          : 'Applied when advertising starts. Each row says which platforms '
                'read it.',
      children: [
        _Choice<AdvertiseMode>(
          label: 'ADVERTISE MODE · ANDROID',
          help: 'How often the advertisement goes out, against battery',
          value: controller.advertiseMode,
          values: AdvertiseMode.values,
          enabled: android && !locked,
          onChanged: (mode) =>
              controller.update(() => controller.advertiseMode = mode),
        ),
        _Choice<AdvertiseTxPower>(
          label: 'TX POWER · ANDROID',
          help: 'How loudly, which sets how far it reaches',
          value: controller.txPower,
          values: AdvertiseTxPower.values,
          enabled: android && !locked,
          onChanged: (power) =>
              controller.update(() => controller.txPower = power),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.connectable,
          onChanged: locked
              ? null
              : (value) =>
                    controller.update(() => controller.connectable = value),
          title: Text('Connectable', style: context.texts.labelLarge),
          subtitle: Text(
            'Off, this is a beacon: discoverable, but nothing can connect and '
            'the GATT service is unreachable.',
            style: context.texts.bodySmall,
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.useOverflowArea,
          onChanged: locked
              ? null
              : (value) =>
                    controller.update(() => controller.useOverflowArea = value),
          title: Text(
            'Overflow area · Apple',
            style: context.texts.labelLarge,
          ),
          subtitle: Text(
            'Keeps the service discoverable to other Apple devices while the '
            'app is in the background.',
            style: context.texts.bodySmall,
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.useExtendedAdvertisement,
          onChanged: locked
              ? null
              : (value) => controller.update(
                  () => controller.useExtendedAdvertisement = value,
                ),
          title: Text(
            'Extended advertisement · Windows',
            style: context.texts.labelLarge,
          ),
          subtitle: Text(
            'Carries more than the 31 bytes a legacy advertisement holds.',
            style: context.texts.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// A labelled row of segmented choices, which reads better than a dropdown for
/// the small enums the radio uses.
class _Choice<T extends Enum> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.help,
    required this.value,
    required this.values,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final String help;
  final T? value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(label, style: tokens.panelLabel),
        Text(help, style: context.texts.bodySmall),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in values)
              _Segment(
                label: option.name,
                selected: option == value,
                onTap: enabled ? () => onChanged(option) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hue = tokens.role.hue;
    return Material(
      color: selected ? hue.withValues(alpha: 0.12) : Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? hue : tokens.hairline),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: tokens.readout.copyWith(
              color: onTap == null
                  ? tokens.inkMuted
                  : (selected ? hue : tokens.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Panel(
      label: 'PERMISSIONS',
      children: [
        ActionRow(
          icon: Icons.checklist,
          title: 'Run the access check',
          subtitle: 'Hardware, then permission, then power',
          onTap: () => ensureRadioReady(context, controller),
        ),
        ActionRow(
          icon: Icons.help_outline,
          title: 'Check permission',
          subtitle: 'Reports what is held without asking for anything',
          onTap: () async {
            final state = await controller.check();
            if (context.mounted) _report(context, 'Permission: ${state.label}');
          },
        ),
        ActionRow(
          icon: Icons.add_moderator,
          title: 'Request permission',
          onTap: () async {
            final state = await controller.request();
            if (context.mounted) _report(context, 'Permission: ${state.label}');
          },
          unavailable: apple
              ? 'Core Bluetooth asks on first use, not on request'
              : null,
        ),
        ActionRow(
          icon: Icons.app_settings_alt,
          title: 'Open app settings',
          onTap: controller.openAppSettings,
        ),
      ],
    );
  }
}

class _AdapterPanel extends StatelessWidget {
  const _AdapterPanel({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Panel(
      label: 'ADAPTER',
      children: [
        Readout(label: 'STATE', value: controller.state.name),
        ActionRow(
          icon: Icons.power_settings_new,
          title: 'Turn the radio on',
          onTap: () async {
            final on = await controller.powerOn();
            if (context.mounted) {
              _report(context, on ? 'Radio on' : 'The radio stayed off');
            }
          },
          unavailable: apple ? 'Apple does not let an app do this' : null,
        ),
        ActionRow(
          icon: Icons.settings_bluetooth,
          title: 'Open Bluetooth settings',
          onTap: controller.openRadioSettings,
        ),
        ActionRow(
          icon: Icons.hardware,
          title: 'Check hardware support',
          onTap: () async {
            final supported = await controller.isSupported;
            if (context.mounted) {
              _report(
                context,
                supported
                    ? 'This device can advertise'
                    : 'This device cannot advertise',
              );
            }
          },
        ),
      ],
    );
  }
}

/// Windows shares one radio between BLE advertising and Nearby Sharing, and
/// the two fight. This is the one panel with no counterpart on the central.
class _WindowsPanel extends StatelessWidget {
  const _WindowsPanel({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    return Panel(
      label: 'WINDOWS',
      footnote:
          'Nearby Sharing holds the advertising slot open for itself. '
          'If advertising starts and nothing ever sees it, turn it off.',
      children: [
        ActionRow(
          icon: Icons.share,
          title: 'Check Nearby Sharing',
          onTap: controller.readNearbyShare,
        ),
        ActionRow(
          icon: Icons.settings,
          title: 'Open sharing settings',
          onTap: controller.openNearbyShareSettings,
        ),
        ActionRow(
          icon: Icons.location_on,
          title: 'Open location settings',
          subtitle: 'Windows needs location before it will report BLE',
          onTap: controller.openLocationSettings,
        ),
      ],
    );
  }
}

void _report(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
