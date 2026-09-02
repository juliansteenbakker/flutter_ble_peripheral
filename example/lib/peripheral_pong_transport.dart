/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ble_peripheral_example/peripheral_controller.dart';
import 'package:flutter_ble_peripheral_example/pong/pong.dart';

/// Carries the game over a real GATT link, as the host.
///
/// The state goes out as a notification on TX, and the central's paddle
/// arrives as a write on RX. That is the same pipe the Data page uses; the
/// game just puts structured bytes through it.
final class PeripheralPongTransport implements PongTransport {
  /// Creates a transport over the controller's own GATT server.
  PeripheralPongTransport(this._controller) {
    _controller.onInbound = _onBytes;
    _controller.isGameRunning = true;
  }

  final PeripheralController _controller;
  final _inbox = StreamController<PongMessage>.broadcast();

  @override
  Stream<PongMessage> get incoming => _inbox.stream;

  /// A peripheral cannot notify a central that never subscribed, so the game
  /// waits for one rather than throwing on every frame.
  @override
  bool get isReady => _controller.isSubscribed;

  @override
  Future<void> send(PongMessage message) async {
    if (!isReady) return;
    await _controller.sendData(message.encode());
  }

  void _onBytes(Uint8List bytes) {
    // Anything at all can arrive on RX, including a payload typed by hand on
    // the Data page. Messages that are not ours are dropped.
    if (PongMessage.decode(bytes) case final message?) _inbox.add(message);
  }

  @override
  Future<void> close() async {
    _controller
      ..onInbound = null
      ..isGameRunning = false;
    await _inbox.close();
  }
}
