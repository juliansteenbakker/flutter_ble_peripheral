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

/// Put this device on the air. The app's primary job.
class LinkPage extends StatelessWidget {
  /// Creates the page over [controller].
  const LinkPage({required this.controller, super.key});

  /// The one controller the app runs on.
  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _AdvertisePanel(controller: controller),
        const SizedBox(height: 12),
        _ServicePanel(controller: controller),
        const SizedBox(height: 12),
        _AdvertiseDataPanel(controller: controller),
      ],
    );
  }
}

class _AdvertisePanel extends StatelessWidget {
  const _AdvertisePanel({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    final advertising = controller.isAdvertising;
    return Panel(
      label: 'ADVERTISE',
      trailing: StateChip(
        label: advertising ? 'on air' : 'off air',
        grade: advertising ? SignalGrade.strong : SignalGrade.none,
        pulsing: advertising,
      ),
      footnote:
          'Everything in an advertisement is a broadcast to whatever is '
          'in range. Treat it as public.',
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: FilledButton(
                onPressed: advertising ? null : controller.startAdvertising,
                child: const Text('Start advertising'),
              ),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: advertising ? controller.stopAdvertising : null,
                child: const Text('Stop'),
              ),
            ),
          ],
        ),
        ReadoutRow([
          Readout(
            label: 'SUBSCRIBED',
            value: controller.isSubscribed ? 'yes' : 'no',
            tint: controller.isSubscribed
                ? SignalGrade.strong.color
                : SignalGrade.none.color,
          ),
          Readout(label: 'MTU', value: controller.mtu?.toString() ?? '—'),
        ]),
      ],
    );
  }
}

/// The GATT service being served, which is what makes this more than a beacon.
class _ServicePanel extends StatelessWidget {
  const _ServicePanel({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    return Panel(
      label: 'GATT SERVICE',
      footnote:
          'TX notifies and can be read; RX takes writes. Both default to '
          'the Nordic UART Service characteristics, so a central that knows '
          'that profile finds them without being told.',
      children: [
        Text(
          'SERVICE  ${controller.serviceUuid}\n'
          'TX       $defaultTxCharacteristicUuid\n'
          'RX       $defaultRxCharacteristicUuid',
          style: context.tokens.readoutDense,
        ),
      ],
    );
  }
}

/// What goes into the advertisement, and how it is broadcast.
class _AdvertiseDataPanel extends StatefulWidget {
  const _AdvertiseDataPanel({required this.controller});

  final PeripheralController controller;

  @override
  State<_AdvertiseDataPanel> createState() => _AdvertiseDataPanelState();
}

class _AdvertiseDataPanelState extends State<_AdvertiseDataPanel> {
  late final _service = TextEditingController(
    text: widget.controller.serviceUuid,
  );
  late final _name = TextEditingController(text: widget.controller.localName);
  late final _manufacturerId = TextEditingController(
    text: widget.controller.manufacturerId?.toString() ?? '',
  );
  late final _manufacturerData = TextEditingController(
    text: formatHexBytes(widget.controller.manufacturerData ?? []),
  );

  PeripheralController get _controller => widget.controller;

  @override
  void dispose() {
    _service.dispose();
    _name.dispose();
    _manufacturerId.dispose();
    _manufacturerData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The advertisement is built when the radio starts, so changing it while
    // it is on the air would say one thing and broadcast another.
    final locked = _controller.isAdvertising;

    return Panel(
      label: 'ADVERTISEMENT',
      footnote: locked
          ? 'Stop advertising to change what is broadcast.'
          : 'Apple broadcasts the service uuid and the local name only. '
                'Everything else is Android and Windows, and neither of them '
                'puts a local name on the air.',
      children: [
        TextField(
          controller: _service,
          enabled: !locked,
          style: context.tokens.readout,
          decoration: const InputDecoration(labelText: 'SERVICE UUID'),
          onChanged: (value) =>
              _controller.update(() => _controller.serviceUuid = value),
        ),
        TextField(
          controller: _name,
          // Greyed off Apple rather than hidden, so the page says which
          // platforms carry a name of their own and which do not.
          enabled: !locked && PeripheralController.carriesLocalName,
          style: context.tokens.readout,
          decoration: InputDecoration(
            labelText: 'LOCAL NAME · APPLE',
            helperText: PeripheralController.carriesLocalName
                ? null
                : 'Not broadcast on ${defaultTargetPlatform.name}',
          ),
          onChanged: (value) =>
              _controller.update(() => _controller.localName = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _controller.includeDeviceName,
          onChanged: locked
              ? null
              : (value) => _controller.update(
                  () => _controller.includeDeviceName = value,
                ),
          title: Text(
            'Include device name · Android',
            style: context.texts.labelLarge,
          ),
          subtitle: Text(
            'Broadcasts the system Bluetooth name, the only name Android can '
            'advertise. It goes in the scan response, since the advertisement '
            'has no room left for it.',
            style: context.texts.bodySmall,
          ),
        ),
        TextField(
          controller: _manufacturerId,
          enabled: !locked,
          style: context.tokens.readout,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'MANUFACTURER ID'),
          onChanged: (value) => _controller.update(
            () => _controller.manufacturerId = int.tryParse(value),
          ),
        ),
        TextField(
          controller: _manufacturerData,
          enabled: !locked,
          style: context.tokens.readout,
          decoration: const InputDecoration(
            labelText: 'MANUFACTURER DATA, HEX BYTES',
          ),
          onChanged: (value) => _controller.update(
            () => _controller.manufacturerData = parseHexBytes(value),
          ),
        ),
      ],
    );
  }
}
