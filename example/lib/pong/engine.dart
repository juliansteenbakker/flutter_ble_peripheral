/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// ignore_for_file: always_use_package_imports

import 'dart:math';

import 'protocol.dart';

/// How wide a paddle is, as a fraction of the court.
const paddleWidth = 0.22;

/// How far along the court a paddle sits from its own wall.
///
/// Far enough in to leave the ball somewhere to be seen arriving, rather than
/// having the hit happen against the edge of the screen.
const paddleInset = 0.07;

/// The ball, as a fraction of the court's width.
const ballRadius = 0.022;

/// Points that win a game.
const pongWinningScore = 7;

/// The rules of the game, with no rendering and no radio in them.
///
/// Only the host runs one. The guest never simulates anything, which is what
/// keeps two devices from disagreeing about the score: there is one authority
/// and the other end draws what it is told.
final class PongEngine {
  /// Creates an engine, optionally with a fixed [seed] so a test can replay a
  /// rally exactly.
  PongEngine({int? seed}) : _random = Random(seed) {
    reset();
  }

  /// How fast the ball travels along the court, in court units a second, when
  /// a rally opens.
  static const _openingSpeed = 0.55;

  /// What each return multiplies the speed by, so a long rally gets harder.
  static const _rallyAcceleration = 1.04;

  /// The ball never travels faster than this, however long the rally.
  static const _terminalSpeed = 1.7;

  /// How long the court holds still after a point, before the next serve.
  static const _serveDelay = Duration(milliseconds: 900);

  final Random _random;

  var _ball = const _Vector(0.5, 0.5);
  var _velocity = const _Vector(0, 0);
  Map<PongSide, double> _paddles = {PongSide.host: 0.5, PongSide.guest: 0.5};
  Map<PongSide, int> _scores = {PongSide.host: 0, PongSide.guest: 0};

  Duration _sinceServe = Duration.zero;
  var _rallying = false;
  var _scored = false;
  var _sequence = 0;

  /// Whether the ball is in play, as opposed to waiting to be served.
  bool get isRallying => _rallying;

  /// Whether someone has reached [pongWinningScore].
  bool get isOver => _scores.values.any((score) => score >= pongWinningScore);

  /// The side that won, or null while the game is still on.
  PongSide? get winner => isOver
      ? (_scores[PongSide.host]! > _scores[PongSide.guest]!
            ? PongSide.host
            : PongSide.guest)
      : null;

  /// Puts the scores back to nil and holds the ball for the first serve.
  void reset() {
    _scores = {PongSide.host: 0, PongSide.guest: 0};
    _paddles = {PongSide.host: 0.5, PongSide.guest: 0.5};
    _hold();
  }

  /// Moves [side]'s paddle so its centre is at [position], from 0 at one wall
  /// to 1 at the other.
  void movePaddle(PongSide side, double position) {
    _paddles[side] = position.clamp(paddleWidth / 2, 1 - paddleWidth / 2);
  }

  /// Advances the simulation by [delta].
  ///
  /// Long steps are cut into short ones, so a frame the platform dropped
  /// cannot carry the ball straight through a paddle.
  void tick(Duration delta) {
    _scored = false;
    if (isOver) return;

    var remaining = delta.inMicroseconds / Duration.microsecondsPerSecond;
    if (remaining <= 0) return;

    if (!_rallying) {
      _sinceServe += delta;
      if (_sinceServe >= _serveDelay) _serve();
      return;
    }

    const step = 1 / 240;
    while (remaining > 0) {
      _step(min(step, remaining));
      remaining -= step;
    }
  }

  void _step(double seconds) {
    _ball = _ball + _velocity * seconds;

    // The side walls are hard: the ball keeps its speed and swaps direction.
    if (_ball.x <= ballRadius && _velocity.x < 0) {
      _ball = _Vector(ballRadius, _ball.y);
      _velocity = _Vector(-_velocity.x, _velocity.y);
    } else if (_ball.x >= 1 - ballRadius && _velocity.x > 0) {
      _ball = _Vector(1 - ballRadius, _ball.y);
      _velocity = _Vector(-_velocity.x, _velocity.y);
    }

    // The guest defends y = 0 and the host defends y = 1.
    if (_velocity.y < 0 && _ball.y <= paddleInset) {
      _resolveEnd(PongSide.guest, paddleInset);
    } else if (_velocity.y > 0 && _ball.y >= 1 - paddleInset) {
      _resolveEnd(PongSide.host, 1 - paddleInset);
    }
  }

  /// Either a return or a point, depending on where the paddle was.
  void _resolveEnd(PongSide defender, double line) {
    final paddle = _paddles[defender]!;
    final offset = (_ball.x - paddle) / (paddleWidth / 2);

    if (offset.abs() > 1 + ballRadius) {
      _scores[defender.opponent] = _scores[defender.opponent]! + 1;
      _scored = true;
      _hold();
      return;
    }

    // Where the ball hits the paddle sets the angle, which is the whole of
    // the game's skill: the edges cut, the middle goes straight back.
    final speed = min(_velocity.length * _rallyAcceleration, _terminalSpeed);
    final angle = offset.clamp(-1.0, 1.0) * (pi / 3);
    final away = defender == PongSide.guest ? 1.0 : -1.0;

    _ball = _Vector(_ball.x, line);
    _velocity = _Vector(sin(angle) * speed, cos(angle) * speed * away);
  }

  void _hold() {
    _rallying = false;
    _sinceServe = Duration.zero;
    _ball = const _Vector(0.5, 0.5);
    _velocity = const _Vector(0, 0);
  }

  void _serve() {
    // Serve towards whoever is behind, and never straight down the middle.
    final trailing = _scores[PongSide.host]! <= _scores[PongSide.guest]!
        ? PongSide.host
        : PongSide.guest;
    final angle = (_random.nextDouble() - 0.5) * (pi / 3);
    final away = trailing == PongSide.guest ? 1.0 : -1.0;

    _ball = const _Vector(0.5, 0.5);
    _velocity = _Vector(
      sin(angle) * _openingSpeed,
      cos(angle) * _openingSpeed * away,
    );
    _rallying = true;
  }

  /// The state to put on the wire, and to draw.
  ///
  /// [acknowledged] is the sequence of the last guest input applied, which the
  /// guest reads back to time the round trip.
  GameState snapshot({int acknowledged = 0}) {
    _sequence = (_sequence + 1) & 0xFF;
    return GameState(
      sequence: _sequence,
      ballX: _ball.x,
      ballY: _ball.y,
      hostPaddle: _paddles[PongSide.host]!,
      guestPaddle: _paddles[PongSide.guest]!,
      hostScore: _scores[PongSide.host]!,
      guestScore: _scores[PongSide.guest]!,
      rallying: _rallying,
      scored: _scored,
      acknowledged: acknowledged,
    );
  }
}

/// A paddle that plays itself.
///
/// It tracks the ball with a speed limit and a standing error, so it is
/// beatable: a perfect tracker would never lose and there would be no game to
/// watch.
final class PongAutoPlayer {
  /// Creates a player of the given [difficulty], from 0 for hopeless to 1 for
  /// nearly perfect.
  PongAutoPlayer({required this.side, this.difficulty = 0.72, int? seed})
    : _random = Random(seed);

  /// The end this player defends.
  final PongSide side;

  /// How well it plays.
  final double difficulty;

  final Random _random;
  double _aim = 0.5;
  double _bias = 0;

  /// Where the paddle should be after [delta], given [state].
  double follow(GameState state, Duration delta) {
    final seconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
    final current = state.paddleOf(side);

    // Re-aim only while the ball is coming this way, so the paddle drifts back
    // towards the middle between rallies rather than mirroring the opponent.
    final incoming = side == PongSide.host
        ? state.ballY > 0.5
        : state.ballY < 0.5;

    if (state.rallying && incoming) {
      if (_random.nextDouble() < 0.04) {
        _bias = (_random.nextDouble() - 0.5) * (1 - difficulty) * 0.8;
      }
      _aim = state.ballX + _bias;
    } else {
      _aim = 0.5;
    }

    final speed = 0.5 + difficulty * 1.4;
    final delta0 = (_aim - current).clamp(-speed * seconds, speed * seconds);
    return (current + delta0).clamp(paddleWidth / 2, 1 - paddleWidth / 2);
  }
}

extension type const _Vector._((double, double) _xy) {
  const _Vector(double x, double y) : this._((x, y));

  double get x => _xy.$1;
  double get y => _xy.$2;

  double get length => sqrt(x * x + y * y);

  _Vector operator +(_Vector other) => _Vector(x + other.x, y + other.y);
  _Vector operator *(double scale) => _Vector(x * scale, y * scale);
}
