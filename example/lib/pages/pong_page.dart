/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral_example/peripheral_controller.dart';
import 'package:flutter_ble_peripheral_example/peripheral_pong_transport.dart';
import 'package:flutter_ble_peripheral_example/pong/pong.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

/// How a game is being played.
enum PongMode {
  /// Two devices, over the real link. This end owns the ball.
  live('Two devices', 'You play the central over the GATT link'),

  /// One device, over a loopback that still encodes and decodes every
  /// message.
  auto('One device', 'Both paddles play themselves over a simulated link');

  const PongMode(this.label, this.blurb);

  /// The word on the selector.
  final String label;

  /// What choosing it does.
  final String blurb;
}

/// The game. The peripheral is always the host: it owns the simulation and
/// notifies the state, because it is the end a central connects to.
class PongPage extends StatefulWidget {
  /// Creates the page over [controller].
  const PongPage({required this.controller, super.key});

  /// The one controller the app runs on.
  final PeripheralController controller;

  @override
  State<PongPage> createState() => _PongPageState();
}

class _PongPageState extends State<PongPage> with TickerProviderStateMixin {
  PongMode _mode = PongMode.auto;
  LoopbackLink? _loopback;
  PeripheralPongTransport? _wire;
  PongHost? _host;
  PongGuest? _localGuest;

  PeripheralController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _mode = _controller.isSubscribed ? PongMode.live : PongMode.auto;
    _build();
  }

  @override
  void dispose() {
    _tearDown();
    super.dispose();
  }

  /// Builds the players for the current mode.
  ///
  /// Auto mode runs a host and a guest in this process, wired to each other
  /// through the loopback. The host is drawn, since that is this device's end
  /// of the court in the real game too.
  void _build() {
    switch (_mode) {
      case PongMode.auto:
        final loopback = LoopbackLink();
        _loopback = loopback;
        _host = PongHost(
          // Counted so the meter reads the same in both modes; over a real
          // link the controller does this on the packets' way through.
          transport: CountedTransport(loopback.host, onPacket: _count),
          vsync: this,
          autoSelf: PongAutoPlayer(side: PongSide.host, difficulty: 0.7),
        );
        _localGuest = PongGuest(
          transport: loopback.guest,
          vsync: this,
          auto: PongAutoPlayer(side: PongSide.guest, difficulty: 0.66),
        );
      case PongMode.live:
        final wire = PeripheralPongTransport(_controller);
        _wire = wire;
        _host = PongHost(
          transport: wire,
          vsync: this,
          // A central that drops out mid-game leaves its paddle behind; the
          // automatic player picks it up rather than the rally freezing.
          autoPeer: PongAutoPlayer(side: PongSide.guest, difficulty: 0.6),
        );
    }
    _host!.resume();
    _localGuest?.resume();
  }

  void _tearDown() {
    _host?.dispose();
    _localGuest?.dispose();
    unawaited(_loopback?.close());
    unawaited(_wire?.close());
    _host = null;
    _localGuest = null;
    _loopback = null;
    _wire = null;
    _controller.telemetry.clear();
  }

  void _switchTo(PongMode mode) {
    if (mode == _mode) return;
    setState(() {
      _tearDown();
      _mode = mode;
      _build();
    });
  }

  void _count({required bool inbound}) => _controller.telemetry.count(
    inbound ? PacketDirection.inbound : PacketDirection.outbound,
  );

  void _start() {
    _host?.start();
    _localGuest?.resume();
  }

  @override
  Widget build(BuildContext context) {
    final host = _host;
    if (host == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _ModeSelector(mode: _mode, onChanged: _switchTo),
          if (_mode == PongMode.live && !_controller.isSubscribed)
            const _NeedsCentral()
          else ...[
            Expanded(child: PongCourt(player: host)),
            PongScoreBar(
              player: host,
              onStart: _start,
              status: (state) => _status(host, state),
            ),
          ],
        ],
      ),
    );
  }

  String _status(PongHost host, GameState? state) {
    if (state != null) {
      if (state.scoreOf(host.side) >= pongWinningScore) return 'You win.';
      if (state.scoreOf(host.side.opponent) >= pongWinningScore) {
        return 'The central wins.';
      }
    }
    if (host.peerIsAuto) {
      return 'The central went quiet, so its paddle is playing itself.';
    }
    if (host.isAuto) return 'Watching. Both paddles are playing themselves.';
    if (!host.peerPresent) {
      return 'Waiting for the central. Nothing has arrived on RX yet.';
    }
    return 'Slide the track below the court, or drag anywhere on the court.';
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final PongMode mode;
  final ValueChanged<PongMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        SegmentedButton<PongMode>(
          segments: [
            for (final option in PongMode.values)
              ButtonSegment(value: option, label: Text(option.label)),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        Text(mode.blurb, style: context.texts.bodySmall),
      ],
    );
  }
}

class _NeedsCentral extends StatelessWidget {
  const _NeedsCentral();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Two-device mode needs a central subscribed to TX. Start '
            'advertising on the Link page, then connect from the '
            'flutter_ble_central example.',
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium,
          ),
        ),
      ),
    );
  }
}
