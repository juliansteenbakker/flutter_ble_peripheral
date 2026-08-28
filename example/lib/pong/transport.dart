/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// ignore_for_file: always_use_package_imports

import 'dart:async';
import 'dart:math';

import 'protocol.dart';

/// A two-way pipe carrying [PongMessage]s.
///
/// The game is written against this and nothing else, which is what lets the
/// same code run over a real GATT link and over the loopback below.
abstract interface class PongTransport {
  /// Messages arriving from the other end.
  Stream<PongMessage> get incoming;

  /// Whether the pipe can carry anything yet.
  bool get isReady;

  /// Puts [message] on the wire.
  ///
  /// The future completes when the platform has taken the payload, which is
  /// what the host paces itself against: sending faster than this completes
  /// only builds a queue, and a stale ball position is worth nothing.
  Future<void> send(PongMessage message);

  /// Stops carrying anything.
  Future<void> close();
}

/// A pair of ends wired to each other in this process.
///
/// This is what the one-device mode runs on. It is not a shortcut around the
/// protocol: messages are encoded, delayed, sometimes dropped and decoded
/// again, so what the court draws is what came off a wire. Turning the delay
/// up is a fair impression of the real thing before you find a second device.
final class LoopbackLink {
  /// Creates a link with [delay] each way and [loss] of packets dropped, from
  /// 0 for a perfect link to 1 for a useless one.
  ///
  /// The default delay is roughly one connection interval on a link that has
  /// asked for high priority, which is what the real thing costs.
  LoopbackLink({
    this.delay = const Duration(milliseconds: 25),
    this.loss = 0,
    int? seed,
  }) : _random = Random(seed) {
    host = _LoopbackEnd(this, () => guest as _LoopbackEnd);
    guest = _LoopbackEnd(this, () => host as _LoopbackEnd);
  }

  /// How long a message spends in flight.
  Duration delay;

  /// The share of messages that never arrive.
  double loss;

  final Random _random;

  /// The end that runs the simulation.
  late final PongTransport host;

  /// The end that sends a paddle and draws what it is told.
  late final PongTransport guest;

  /// Closes both ends.
  Future<void> close() async {
    await host.close();
    await guest.close();
  }
}

class _LoopbackEnd implements PongTransport {
  _LoopbackEnd(this._link, this._other);

  final LoopbackLink _link;
  final _LoopbackEnd Function() _other;
  final _inbox = StreamController<PongMessage>.broadcast();
  var _open = true;

  @override
  Stream<PongMessage> get incoming => _inbox.stream;

  @override
  bool get isReady => _open;

  @override
  Future<void> send(PongMessage message) async {
    if (!_open) return;
    // Encoded and decoded rather than handed over, so the one-device mode
    // exercises the same wire format the radio does.
    final bytes = message.encode();
    if (_link._random.nextDouble() < _link.loss) return;

    Timer(_link.delay, () {
      final other = _other();
      if (!other._open) return;
      if (PongMessage.decode(bytes) case final decoded?) {
        other._inbox.add(decoded);
      }
    });
  }

  @override
  Future<void> close() async {
    _open = false;
    await _inbox.close();
  }
}

/// Wraps a transport and reports every message that crosses it.
///
/// The real link is counted by the plugin controller on its way through, but
/// the loopback has no radio behind it, so the one-device mode wraps its ends
/// in this to keep the link meter honest.
final class CountedTransport implements PongTransport {
  /// Wraps [inner], calling [onPacket] with true for messages arriving and
  /// false for messages sent.
  CountedTransport(this.inner, {required this.onPacket});

  /// The transport doing the actual carrying.
  final PongTransport inner;

  /// Called once per message, in either direction.
  final void Function({required bool inbound}) onPacket;

  @override
  Stream<PongMessage> get incoming => inner.incoming.map((message) {
    onPacket(inbound: true);
    return message;
  });

  @override
  bool get isReady => inner.isReady;

  @override
  Future<void> send(PongMessage message) {
    onPacket(inbound: false);
    return inner.send(message);
  }

  @override
  Future<void> close() => inner.close();
}
