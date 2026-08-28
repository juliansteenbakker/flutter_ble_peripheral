/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.

import 'dart:typed_data';

/// The version this build speaks.
///
/// It rides in every [Hello] so a new example talking to an old one says so
/// rather than playing garbage.
const pongProtocolVersion = 1;

/// The longest message the protocol will ever produce.
///
/// The default ATT MTU is 23 bytes, of which 20 carry payload, and neither
/// Core Bluetooth nor WinRT lets a central insist on more. Every message is
/// sized to fit that, so a game works without negotiating anything.
const pongMaxMessageLength = 20;

/// The court is this many protocol units on each side.
///
/// Positions cross the link as integers in this space and each side scales
/// them to its own screen, so two devices with different screens agree on
/// where the ball is.
const pongCourtSize = 1000;

/// Which end of the court a player defends.
enum PongSide {
  /// The peripheral, which owns the simulation.
  host,

  /// The central, which sends its paddle and renders what it is told.
  guest;

  /// The other end.
  PongSide get opponent => this == host ? guest : host;
}

/// What a [Control] message asks for.
enum PongCommand {
  /// Start a new game, scores back to nil.
  start,

  /// Stop the rally and hold.
  pause,

  /// Resume a held rally.
  resume;

  static PongCommand? _from(int code) =>
      code < PongCommand.values.length ? PongCommand.values[code] : null;
}

/// One message on the wire.
///
/// Every message starts with a type byte, so a receiver can tell them apart
/// without a length prefix or a framing layer: BLE already delivers one write
/// or one notification as one whole message.
sealed class PongMessage {
  const PongMessage();

  /// Reads a message, or returns null when the bytes are not one.
  ///
  /// Returning null rather than throwing is deliberate: anything at all can
  /// arrive on a characteristic, including a payload someone typed by hand on
  /// the Data page while a game is running.
  static PongMessage? decode(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final data = ByteData.sublistView(bytes);
    return switch (bytes.first) {
      Hello._type when bytes.length >= 2 => Hello(version: bytes[1]),
      PaddleInput._type when bytes.length >= 3 => PaddleInput(
        sequence: bytes[1],
        position: bytes[2] / 255,
      ),
      Control._type when bytes.length >= 2 => _control(bytes[1]),
      GameState._type when bytes.length >= 12 => GameState(
        sequence: bytes[1],
        ballX: data.getUint16(2) / pongCourtSize,
        ballY: data.getUint16(4) / pongCourtSize,
        hostPaddle: bytes[6] / 255,
        guestPaddle: bytes[7] / 255,
        hostScore: bytes[8],
        guestScore: bytes[9],
        rallying: bytes[10] & 0x01 != 0,
        scored: bytes[10] & 0x02 != 0,
        acknowledged: bytes[11],
      ),
      _ => null,
    };
  }

  static PongMessage? _control(int code) {
    final command = PongCommand._from(code);
    return command == null ? null : Control(command);
  }

  /// The bytes to put on the characteristic.
  Uint8List encode();
}

/// Sent on connecting, so both ends know they are talking to the same game.
final class Hello extends PongMessage {
  /// Creates a hello carrying [version].
  const Hello({this.version = pongProtocolVersion});

  static const _type = 0x01;

  /// The protocol version the sender speaks.
  final int version;

  /// Whether that is the version this build understands.
  bool get isCompatible => version == pongProtocolVersion;

  @override
  Uint8List encode() => Uint8List.fromList([_type, version]);
}

/// The guest's paddle, sent to the host.
///
/// Only the paddle: the guest simulates nothing, so there is nothing else it
/// could authoritatively say.
final class PaddleInput extends PongMessage {
  /// Creates an input at [position], from 0 at one wall to 1 at the other.
  const PaddleInput({required this.sequence, required this.position});

  static const _type = 0x03;

  /// Wraps at 256. Only useful for spotting loss in the traffic log.
  final int sequence;

  /// Where the paddle's centre is, across the court.
  final double position;

  @override
  Uint8List encode() => Uint8List.fromList([
    _type,
    sequence & 0xFF,
    (position.clamp(0.0, 1.0) * 255).round(),
  ]);
}

/// Start, pause or resume, sent either way.
final class Control extends PongMessage {
  /// Creates a control message asking for [command].
  const Control(this.command);

  static const _type = 0x04;

  /// What is being asked for.
  final PongCommand command;

  @override
  Uint8List encode() => Uint8List.fromList([_type, command.index]);
}

/// The whole game, as the host sees it.
///
/// The host is the only authority, so this is not a delta or a correction: it
/// is the truth, and a guest that misses one simply uses the next.
final class GameState extends PongMessage {
  /// Creates a state.
  const GameState({
    required this.sequence,
    required this.ballX,
    required this.ballY,
    required this.hostPaddle,
    required this.guestPaddle,
    required this.hostScore,
    required this.guestScore,
    required this.rallying,
    required this.scored,
    required this.acknowledged,
  });

  static const _type = 0x02;

  /// Wraps at 256. The guest uses it to drop a state that arrived late.
  final int sequence;

  /// The ball, across the court, from 0 to 1.
  final double ballX;

  /// The ball, along the court, 0 at the guest's wall and 1 at the host's.
  final double ballY;

  /// The host's paddle centre, across the court.
  final double hostPaddle;

  /// The guest's paddle centre, across the court.
  final double guestPaddle;

  /// Points the host has.
  final int hostScore;

  /// Points the guest has.
  final int guestScore;

  /// Whether the ball is in play.
  final bool rallying;

  /// Whether a point landed on the frame this state describes.
  final bool scored;

  /// The sequence of the last [PaddleInput] the host applied.
  ///
  /// The guest times the round trip against this, which is what the link
  /// meter plots while a game is on.
  final int acknowledged;

  /// The paddle belonging to [side].
  double paddleOf(PongSide side) =>
      side == PongSide.host ? hostPaddle : guestPaddle;

  /// The score belonging to [side].
  int scoreOf(PongSide side) => side == PongSide.host ? hostScore : guestScore;

  @override
  Uint8List encode() {
    final bytes = Uint8List(12);
    ByteData.sublistView(bytes)
      ..setUint8(0, _type)
      ..setUint8(1, sequence & 0xFF)
      ..setUint16(2, (ballX.clamp(0.0, 1.0) * pongCourtSize).round())
      ..setUint16(4, (ballY.clamp(0.0, 1.0) * pongCourtSize).round())
      ..setUint8(6, (hostPaddle.clamp(0.0, 1.0) * 255).round())
      ..setUint8(7, (guestPaddle.clamp(0.0, 1.0) * 255).round())
      ..setUint8(8, hostScore.clamp(0, 255))
      ..setUint8(9, guestScore.clamp(0, 255))
      ..setUint8(10, (rallying ? 0x01 : 0) | (scored ? 0x02 : 0))
      ..setUint8(11, acknowledged & 0xFF);
    return bytes;
  }
}
