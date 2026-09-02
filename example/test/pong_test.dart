/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// Relative so this file reads the same in both repositories; a package import
// would have to name one example or the other.
// ignore: avoid_relative_lib_imports
import '../lib/pong/pong.dart';

void main() {
  group('protocol', () {
    test('every message fits the default ATT payload', () {
      final messages = <PongMessage>[
        const Hello(),
        const Control(PongCommand.start),
        const PaddleInput(sequence: 200, position: 0.5),
        PongEngine(seed: 1).snapshot(acknowledged: 12),
      ];
      for (final message in messages) {
        expect(
          message.encode().length,
          lessThanOrEqualTo(pongMaxMessageLength),
          reason: '$message must fit an unnegotiated MTU',
        );
      }
    });

    test('a state survives the round trip', () {
      final engine = PongEngine(seed: 7)
        ..movePaddle(PongSide.guest, 0.25)
        ..tick(const Duration(seconds: 2));
      final sent = engine.snapshot(acknowledged: 9);

      final received = PongMessage.decode(sent.encode());

      expect(received, isA<GameState>());
      final state = received! as GameState;
      expect(state.sequence, sent.sequence);
      expect(state.acknowledged, 9);
      expect(state.hostScore, sent.hostScore);
      expect(state.guestScore, sent.guestScore);
      expect(state.rallying, sent.rallying);
      // A byte of resolution across the court, so a paddle lands within half
      // of one.
      expect(state.guestPaddle, closeTo(sent.guestPaddle, 1 / 255));
      expect(state.ballX, closeTo(sent.ballX, 1 / pongCourtSize));
      expect(state.ballY, closeTo(sent.ballY, 1 / pongCourtSize));
    });

    test('an input survives the round trip', () {
      const sent = PaddleInput(sequence: 255, position: 0.8);
      final received = PongMessage.decode(sent.encode())! as PaddleInput;

      expect(received.sequence, 255);
      expect(received.position, closeTo(0.8, 1 / 255));
    });

    test('anything that is not a message decodes to null', () {
      expect(PongMessage.decode(Uint8List(0)), isNull);
      expect(PongMessage.decode(Uint8List.fromList([0xFF, 1, 2])), isNull);
      // A truncated state, which is what a peer speaking an older protocol
      // would send.
      expect(PongMessage.decode(Uint8List.fromList([0x02, 1, 2])), isNull);
    });

    test('a hello from another version is rejected', () {
      const theirs = Hello(version: pongProtocolVersion + 1);
      final received = PongMessage.decode(theirs.encode())! as Hello;

      expect(received.isCompatible, isFalse);
      expect(const Hello().isCompatible, isTrue);
    });
  });

  group('engine', () {
    test('holds the ball, then serves it', () {
      final engine = PongEngine(seed: 3);
      expect(engine.isRallying, isFalse);

      engine.tick(const Duration(milliseconds: 500));
      expect(
        engine.isRallying,
        isFalse,
        reason: 'still inside the serve delay',
      );

      engine.tick(const Duration(milliseconds: 500));
      expect(engine.isRallying, isTrue);
    });

    test('a paddle in the way returns the ball', () {
      final engine = PongEngine(seed: 3)..tick(const Duration(seconds: 1));

      // Track the ball with both paddles, so nobody can miss.
      var ticks = 0;
      while (ticks < 600) {
        final state = engine.snapshot();
        engine
          ..movePaddle(PongSide.host, state.ballX)
          ..movePaddle(PongSide.guest, state.ballX)
          ..tick(const Duration(milliseconds: 16));
        ticks++;
      }

      final state = engine.snapshot();
      expect(state.hostScore, 0);
      expect(state.guestScore, 0);
      expect(state.rallying, isTrue, reason: 'the rally never broke');
    });

    test('a paddle out of the way concedes a point', () {
      final engine = PongEngine(seed: 3)..tick(const Duration(seconds: 1));

      for (var tick = 0; tick < 900; tick++) {
        engine
          ..movePaddle(PongSide.host, 0)
          ..movePaddle(PongSide.guest, 1)
          ..tick(const Duration(milliseconds: 16));
      }

      final state = engine.snapshot();
      expect(state.hostScore + state.guestScore, greaterThan(0));
    });

    test('the ball stays on the court', () {
      final engine = PongEngine(seed: 11);
      for (var tick = 0; tick < 2000; tick++) {
        engine.tick(const Duration(milliseconds: 16));
        final state = engine.snapshot();
        expect(state.ballX, inInclusiveRange(0, 1));
        expect(state.ballY, inInclusiveRange(0, 1));
      }
    });

    test('a long step cannot carry the ball through a paddle', () {
      final fine = PongEngine(seed: 5)..tick(const Duration(seconds: 1));
      final coarse = PongEngine(seed: 5)..tick(const Duration(seconds: 1));

      for (var tick = 0; tick < 120; tick++) {
        for (var sub = 0; sub < 10; sub++) {
          fine
            ..movePaddle(PongSide.host, fine.snapshot().ballX)
            ..movePaddle(PongSide.guest, fine.snapshot().ballX)
            ..tick(const Duration(milliseconds: 10));
        }
        coarse
          ..movePaddle(PongSide.host, coarse.snapshot().ballX)
          ..movePaddle(PongSide.guest, coarse.snapshot().ballX)
          ..tick(const Duration(milliseconds: 100));
      }

      expect(fine.snapshot().hostScore + fine.snapshot().guestScore, 0);
      expect(coarse.snapshot().hostScore + coarse.snapshot().guestScore, 0);
    });

    test('a game ends when someone reaches the winning score', () {
      final engine = PongEngine(seed: 2);
      for (var tick = 0; tick < 20000 && !engine.isOver; tick++) {
        engine
          ..movePaddle(PongSide.host, engine.snapshot().ballX)
          ..movePaddle(PongSide.guest, 0)
          ..tick(const Duration(milliseconds: 16));
      }

      expect(engine.isOver, isTrue);
      expect(engine.winner, PongSide.host);
      expect(engine.snapshot().hostScore, pongWinningScore);
    });
  });

  group('automatic player', () {
    test('beats a paddle that never moves', () {
      final engine = PongEngine(seed: 4);
      final auto = PongAutoPlayer(side: PongSide.host, seed: 4);
      const frame = Duration(milliseconds: 16);

      for (var tick = 0; tick < 20000 && !engine.isOver; tick++) {
        engine
          ..movePaddle(PongSide.host, auto.follow(engine.snapshot(), frame))
          ..movePaddle(PongSide.guest, 0.05)
          ..tick(frame);
      }

      expect(engine.winner, PongSide.host);
    });
  });
}
