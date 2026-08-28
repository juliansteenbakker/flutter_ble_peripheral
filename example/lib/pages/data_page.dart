/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral_example/peripheral_controller.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

/// Exchange bytes with whatever connected, and ask the plugin where things
/// stand.
class DataPage extends StatefulWidget {
  /// Creates the page over [controller].
  const DataPage({required this.controller, super.key});

  /// The one controller the app runs on.
  final PeripheralController controller;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final _payload = TextEditingController(text: '01 02 03');

  PeripheralController get _controller => widget.controller;

  @override
  void dispose() {
    _payload.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final bytes = parseHexBytes(_payload.text);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter hex bytes, such as 01 02 03')),
      );
      return;
    }
    await _controller.sendData(bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAdvertising) return const _OffAir();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _exchange(context),
        const SizedBox(height: 12),
        _queries(),
      ],
    );
  }

  Widget _exchange(BuildContext context) {
    final subscribed = _controller.isSubscribed;
    return Panel(
      label: 'EXCHANGE',
      trailing: StateChip(
        label: subscribed ? 'subscribed' : 'nobody listening',
        grade: subscribed ? SignalGrade.strong : SignalGrade.weak,
        pulsing: !subscribed,
      ),
      footnote:
          'Notifications go to every subscribed central. They queue per '
          'central, so back-to-back sends arrive in order rather than '
          'overwriting each other.',
      children: [
        TextField(
          controller: _payload,
          style: context.tokens.readout,
          decoration: const InputDecoration(labelText: 'PAYLOAD, HEX BYTES'),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F ,]')),
          ],
        ),
        FilledButton(
          onPressed: subscribed ? _send : null,
          child: const Text('Notify on TX'),
        ),
        if (!subscribed)
          Text(
            'Send stays off until a central subscribes: a peripheral cannot '
            'notify one that never asked to be notified.',
            style: context.texts.bodySmall,
          ),
        const Divider(),
        _TrafficLog(controller: _controller),
      ],
    );
  }

  Widget _queries() {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Panel(
      label: 'STATE',
      footnote: apple
          ? 'Core Bluetooth never reports a bare connection, so a central '
                'becomes visible here only once it subscribes, reads or writes.'
          : null,
      children: [
        ActionRow(
          icon: Icons.link,
          title: 'Is a central connected',
          onTap: _controller.readIsConnected,
        ),
        ActionRow(
          icon: Icons.notifications_active,
          title: 'Is a central subscribed',
          subtitle: 'What gates the Notify button',
          onTap: _controller.readIsSubscribed,
        ),
        ActionRow(
          icon: Icons.podcasts,
          title: 'Is the advertisement on the air',
          onTap: _controller.readIsAdvertising,
        ),
      ],
    );
  }
}

class _TrafficLog extends StatelessWidget {
  const _TrafficLog({required this.controller});

  final PeripheralController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final traffic = controller.traffic;
    if (traffic.isEmpty) {
      return Text(
        'Nothing has crossed the link yet.',
        style: context.texts.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        for (final packet in traffic.take(12))
          Row(
            spacing: 8,
            children: [
              Text(
                switch (packet.direction) {
                  PacketDirection.outbound => '↑',
                  PacketDirection.inbound => '↓',
                },
                style: tokens.readoutDense.copyWith(
                  color: packet.direction == PacketDirection.outbound
                      ? tokens.role.hue
                      : tokens.ink,
                ),
              ),
              Expanded(
                child: Text(
                  formatHexBytes(packet.bytes),
                  style: tokens.readout,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${packet.bytes.length} B', style: tokens.readoutDense),
            ],
          ),
      ],
    );
  }
}

class _OffAir extends StatelessWidget {
  const _OffAir();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Start advertising on the Link page. The GATT server opens with it, '
          'and everything a connected central can do appears here.',
          textAlign: TextAlign.center,
          style: context.texts.bodyMedium,
        ),
      ),
    );
  }
}
