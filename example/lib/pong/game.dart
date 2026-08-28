/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// ignore_for_file: always_use_package_imports

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'engine.dart';
import 'protocol.dart';
import 'transport.dart';

/// One end of a game.
///
/// Both ends present the same face to the court that draws them: a state to
/// render, a side to render it from, and a paddle to push around.
sealed class PongPlayer extends ChangeNotifier {
  PongPlayer._(this._transport, TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
    _incoming = _transport.incoming.listen(_onMessage);
  }

  final PongTransport _transport;
  late final Ticker _ticker;
  late final StreamSubscription<PongMessage> _incoming;

  Duration _previous = Duration.zero;

  /// The end this player is sitting at, which is the end drawn nearest.
  PongSide get side;

  /// What to draw, or null before the first state exists.
  GameState? get state;

  /// The round trip of the link, once it has been measured.
  Duration? get roundTrip => null;

  /// Whether the other end is answering.
  bool get peerPresent;

  /// Whether an automatic player is holding this end's paddle.
  bool get isAuto;

  /// Puts this end's paddle at [position], from 0 at one wall to 1 at the
  /// other. Ignored while an automatic player has it.
  void aim(double position);

  /// Starts, or restarts, a game.
  void start();

  /// Runs once a frame.
  void _onTick(Duration elapsed) {
    final delta = elapsed - _previous;
    _previous = elapsed;
    if (delta > Duration.zero) advance(delta);
  }

  /// Advances this end by [delta].
  @protected
  void advance(Duration delta);

  /// Handles one message from the other end.
  @protected
  void handle(PongMessage message);

  void _onMessage(PongMessage message) => handle(message);

  /// Begins running frames.
  void resume() {
    _previous = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  /// Stops running frames, without closing the link.
  void pause() => _ticker.stop();

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_incoming.cancel());
    super.dispose();
  }
}

/// The authority: it simulates the game and tells the other end what happened.
///
/// The peripheral runs this, because it is the end a central connects to. It
/// is also what the one-device mode runs, over the loopback.
final class PongHost extends PongPlayer {
  /// Creates a host.
  ///
  /// [autoSelf] plays this end's own paddle, which is what the one-device mode
  /// uses. [autoPeer] takes the other end's paddle when nothing is arriving
  /// from it, so a game carries on through a disconnect instead of freezing.
  PongHost({
    required PongTransport transport,
    required TickerProvider vsync,
    this.autoSelf,
    this.autoPeer,
    int? seed,
  }) : _engine = PongEngine(seed: seed),
       super._(transport, vsync);

  /// How often the host puts the state on the wire.
  ///
  /// Twenty a second is comfortably inside what a 15 ms connection interval
  /// carries, and the send is awaited besides, so this is a ceiling rather
  /// than a promise.
  static const _sendInterval = Duration(milliseconds: 50);

  /// How long the peer can stay silent before the automatic player takes its
  /// paddle.
  static const _peerTimeout = Duration(milliseconds: 1200);

  /// Plays this end's paddle, or null when a person does.
  final PongAutoPlayer? autoSelf;

  /// Plays the other end's paddle when it goes quiet.
  final PongAutoPlayer? autoPeer;

  final PongEngine _engine;

  GameState _state = PongEngine().snapshot();
  Duration _sinceSend = Duration.zero;
  Duration _sinceInput = _peerTimeout;
  int _acknowledged = 0;
  bool _sending = false;

  @override
  PongSide get side => PongSide.host;

  @override
  GameState get state => _state;

  @override
  bool get peerPresent => _sinceInput < _peerTimeout;

  @override
  bool get isAuto => autoSelf != null;

  /// Whether the automatic player is currently covering for the other end.
  bool get peerIsAuto => !peerPresent && autoPeer != null;

  @override
  void aim(double position) {
    if (autoSelf != null) return;
    _engine.movePaddle(PongSide.host, position);
  }

  @override
  void start() {
    _engine.reset();
    unawaited(_transport.send(const Control(PongCommand.start)));
    resume();
  }

  @override
  void advance(Duration delta) {
    _sinceInput += delta;

    if (autoSelf case final auto?) {
      _engine.movePaddle(side, auto.follow(_state, delta));
    }
    if (peerIsAuto) {
      _engine.movePaddle(
        PongSide.guest,
        autoPeer!.follow(_state, delta),
      );
    }

    _engine.tick(delta);
    _state = _engine.snapshot(acknowledged: _acknowledged);
    notifyListeners();

    _sinceSend += delta;
    if (_sinceSend >= _sendInterval) _publish();
  }

  /// Sends the state, skipping a turn while the previous send is still going.
  ///
  /// This is the whole of the flow control: the wire is never asked to carry
  /// more than it is draining, and the state that gets dropped is always the
  /// older one.
  void _publish() {
    if (_sending || !_transport.isReady) return;
    _sinceSend = Duration.zero;
    _sending = true;
    unawaited(
      _transport.send(_state).whenComplete(() => _sending = false),
    );
  }

  @override
  void handle(PongMessage message) {
    switch (message) {
      case PaddleInput(:final position, :final sequence):
        _sinceInput = Duration.zero;
        _acknowledged = sequence;
        _engine.movePaddle(PongSide.guest, position);
      case Hello():
        unawaited(_transport.send(const Hello()));
      case Control(command: PongCommand.start):
        start();
      case Control(command: PongCommand.pause):
        pause();
      case Control(command: PongCommand.resume):
        resume();
      case GameState():
      // Two hosts on one link would be a bug in the app, not in the game.
    }
  }
}

/// The other end: it sends a paddle and draws what it is told.
///
/// The central runs this. It never simulates the ball, so it cannot disagree
/// with the host about the score however bad the link gets.
final class PongGuest extends PongPlayer {
  /// Creates a guest. [auto] plays its paddle instead of a person.
  PongGuest({
    required PongTransport transport,
    required TickerProvider vsync,
    this.auto,
  }) : super._(transport, vsync);

  /// How often the paddle goes out. Matching the host's rate keeps the two
  /// directions symmetrical in the traffic log.
  static const _sendInterval = Duration(milliseconds: 50);

  /// How long the host can stay silent before the link counts as dead.
  static const _hostTimeout = Duration(milliseconds: 1500);

  /// Plays this end's paddle, or null when a person does.
  final PongAutoPlayer? auto;

  GameState? _state;
  Duration _sinceState = _hostTimeout;
  Duration _sinceSend = Duration.zero;
  Duration? _roundTrip;
  double _paddle = 0.5;
  int _sequence = 0;
  bool _sending = false;

  final _sentAt = <int, Duration>{};
  Duration _clock = Duration.zero;

  @override
  PongSide get side => PongSide.guest;

  @override
  GameState? get state => _state;

  @override
  Duration? get roundTrip => _roundTrip;

  @override
  bool get peerPresent => _sinceState < _hostTimeout;

  @override
  bool get isAuto => auto != null;

  @override
  void aim(double position) {
    if (auto != null) return;
    _paddle = position.clamp(0.0, 1.0);
  }

  @override
  void start() {
    unawaited(_transport.send(const Control(PongCommand.start)));
    resume();
  }

  @override
  void advance(Duration delta) {
    _clock += delta;
    _sinceState += delta;
    _sinceSend += delta;

    if (auto case final auto? when _state != null) {
      _paddle = auto.follow(_state!, delta);
    }
    if (_sinceSend >= _sendInterval) _publish();
  }

  void _publish() {
    if (_sending || !_transport.isReady) return;
    _sinceSend = Duration.zero;
    _sequence = (_sequence + 1) & 0xFF;
    _sentAt[_sequence] = _clock;
    // Only the last few can still be acknowledged; the rest are history.
    if (_sentAt.length > 24) {
      _sentAt.remove(_sentAt.keys.first);
    }

    _sending = true;
    unawaited(
      _transport
          .send(PaddleInput(sequence: _sequence, position: _paddle))
          .whenComplete(() => _sending = false),
    );
  }

  @override
  void handle(PongMessage message) {
    switch (message) {
      case GameState():
        // A state that arrived out of order is older than what is on screen,
        // and the newest state is the only one worth drawing.
        if (_state case final current? when _isStale(message, current)) return;
        _sinceState = Duration.zero;
        _state = message;
        if (_sentAt.remove(message.acknowledged) case final sent?) {
          _roundTrip = _clock - sent;
        }
        notifyListeners();
      case Hello():
        unawaited(_transport.send(const Hello()));
      case Control() || PaddleInput():
      // The host decides; nothing here to act on.
    }
  }

  /// Whether [candidate] is older than [current], allowing for the sequence
  /// wrapping at 256.
  bool _isStale(GameState candidate, GameState current) {
    final gap = (candidate.sequence - current.sequence) & 0xFF;
    return gap == 0 || gap > 128;
  }
}
