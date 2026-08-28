/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// ignore_for_file: always_use_package_imports

import 'dart:math';

import 'package:flutter/material.dart';

import '../shell/theme.dart';
import 'engine.dart';
import 'game.dart';
import 'protocol.dart';

/// The widest the court is allowed to get on a large screen, as width over
/// height.
///
/// A court stretched across a desktop window turns the ball into a blob and
/// the paddles into slivers, so on anything roomy it keeps its shape and sits
/// in the middle.
const _maxCourtAspect = 0.85;

/// Below this width the screen is a phone, and the court takes all of it.
///
/// Width is the scarce thing in a hand: the paddle travels across it, so
/// giving the court every pixel of it matters more than its proportions.
const _phoneWidth = 600.0;

/// How tall the paddle control is. Wide enough for a thumb, on purpose.
const _height = 66.0;

/// The court and the control that drives it.
///
/// Whoever is holding the device is always at the bottom, so the two players
/// each see themselves in the same place. The paddle is never driven by
/// touching it: a finger on the paddle covers exactly the thing you need to
/// watch, which is the ball arriving at it.
class PongCourt extends StatelessWidget {
  /// Creates a court showing [player].
  const PongCourt({required this.player, super.key});

  /// The end being drawn, and the end the control drives.
  final PongPlayer player;

  /// The gap between the court and the control under it.
  static const _gutter = 10.0;

  @override
  Widget build(BuildContext context) {
    // An automatic player takes no instruction, so it gets no control.
    final control = player.isAuto ? null : PaddleControl(player: player);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The width is settled here rather than inside the court, because the
        // control has to be exactly as wide as the court it drives: the thumb
        // maps straight across, and a control wider than the court would put
        // the paddle somewhere other than under the finger.
        final courtHeight =
            constraints.maxHeight - (control == null ? 0 : _height + _gutter);
        final roomy = MediaQuery.sizeOf(context).width >= _phoneWidth;
        final width = roomy
            ? min(constraints.maxWidth, courtHeight * _maxCourtAspect)
            : constraints.maxWidth;

        return Center(
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _gutter,
              children: [
                Expanded(child: _CourtSurface(player: player)),
                ?control,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CourtSurface extends StatefulWidget {
  const _CourtSurface({required this.player});

  final PongPlayer player;

  @override
  State<_CourtSurface> createState() => _CourtSurfaceState();
}

class _CourtSurfaceState extends State<_CourtSurface> {
  /// How many past positions the ball leaves behind it.
  static const _trailLength = 14;

  final _trail = <Offset>[];
  int? _lastSequence;

  /// Where a drag started, and where the paddle was when it did.
  ///
  /// The court steers by how far the finger has moved rather than by where it
  /// is, so a drag can be started anywhere — including well away from the
  /// paddle — and still control it.
  double? _anchorX;
  double? _anchorPaddle;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onFrame);
  }

  @override
  void didUpdateWidget(_CourtSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player.removeListener(_onFrame);
      widget.player.addListener(_onFrame);
      _trail.clear();
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    final state = widget.player.state;
    if (state == null || state.sequence == _lastSequence) return;
    _lastSequence = state.sequence;

    if (state.scored) _trail.clear();
    _trail.add(Offset(state.ballX, state.ballY));
    if (_trail.length > _trailLength) _trail.removeAt(0);
    setState(() {});
  }

  void _startDrag(Offset local) {
    _anchorX = local.dx;
    _anchorPaddle = widget.player.state?.paddleOf(widget.player.side) ?? 0.5;
  }

  void _continueDrag(Offset local, Size size) {
    if (_anchorX case final anchor? when size.width > 0) {
      final travelled = (local.dx - anchor) / size.width;
      widget.player.aim((_anchorPaddle ?? 0.5) + travelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = widget.player;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _startDrag(details.localPosition),
          onPanUpdate: (details) => _continueDrag(details.localPosition, size),
          onPanEnd: (_) => _anchorX = null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.chassis,
              border: Border.all(color: tokens.hairline),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: CustomPaint(
                painter: _CourtPainter(
                  state: player.state,
                  trail: _trail,
                  side: player.side,
                  graticule: tokens.graticule,
                  near: tokens.role.hue,
                  far: tokens.ink,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The track the paddle is driven from: a strip below the court, well clear of
/// where the ball arrives.
///
/// It maps straight across, so the thumb sits under your finger and the paddle
/// sits at the same place on the court. Dragging on the court works too, but
/// relatively rather than absolutely.
class PaddleControl extends StatefulWidget {
  /// Creates a control for [player].
  const PaddleControl({required this.player, super.key});

  /// The end being driven.
  final PongPlayer player;

  @override
  State<PaddleControl> createState() => _PaddleControlState();
}

class _PaddleControlState extends State<PaddleControl> {
  var _holding = false;

  void _aimAt(Offset local, double width) {
    if (width <= 0) return;
    // The usable travel is narrower than the strip by half a paddle at each
    // end, so the thumb reaches the wall exactly when the paddle does.
    const margin = paddleWidth / 2;
    final fraction = (local.dx / width).clamp(0.0, 1.0);
    widget.player.aim(margin + fraction * (1 - paddleWidth));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: widget.player,
      builder: (context, _) {
        final paddle = widget.player.state?.paddleOf(widget.player.side) ?? 0.5;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Semantics(
              slider: true,
              label: 'Paddle',
              value: '${(paddle * 100).round()} percent across',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) {
                  setState(() => _holding = true);
                  _aimAt(details.localPosition, width);
                },
                onPanUpdate: (details) => _aimAt(details.localPosition, width),
                onPanEnd: (_) => setState(() => _holding = false),
                onPanCancel: () => setState(() => _holding = false),
                child: SizedBox(
                  height: _height,
                  child: CustomPaint(
                    painter: _ControlPainter(
                      paddle: paddle,
                      holding: _holding,
                      graticule: tokens.graticule,
                      hairline: tokens.hairline,
                      hue: tokens.role.hue,
                      panel: tokens.panel,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ControlPainter extends CustomPainter {
  _ControlPainter({
    required this.paddle,
    required this.holding,
    required this.graticule,
    required this.hairline,
    required this.hue,
    required this.panel,
  });

  final double paddle;
  final bool holding;
  final Color graticule;
  final Color hairline;
  final Color hue;
  final Color panel;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(body, Paint()..color = panel)
      ..drawRRect(
        body,
        Paint()
          ..color = hairline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    // Ticks at the walls, quarters and centre, so the travel is legible at
    // rest.
    final tick = Paint()
      ..color = graticule
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final x = (size.width * fraction).clamp(1.0, size.width - 1);
      final inset = fraction == 0.5 ? 12.0 : 20.0;
      canvas.drawLine(
        Offset(x, inset),
        Offset(x, size.height - inset),
        tick,
      );
    }

    // The thumb is drawn the width the paddle actually covers, so the control
    // is a scale model of the court rather than a generic slider.
    final thumbWidth = paddleWidth * size.width;
    final travel = size.width - thumbWidth;
    const margin = paddleWidth / 2;
    final fraction = ((paddle - margin) / (1 - paddleWidth)).clamp(0.0, 1.0);
    final left = travel * fraction;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 10, thumbWidth, size.height - 20),
          const Radius.circular(6),
        ),
        Paint()..color = hue.withValues(alpha: holding ? 0.42 : 0.24),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height / 2 - 2, thumbWidth, 4),
          const Radius.circular(2),
        ),
        Paint()..color = hue,
      );
  }

  @override
  bool shouldRepaint(_ControlPainter oldDelegate) =>
      oldDelegate.paddle != paddle ||
      oldDelegate.holding != holding ||
      oldDelegate.hue != hue;
}

class _CourtPainter extends CustomPainter {
  _CourtPainter({
    required this.state,
    required this.trail,
    required this.side,
    required this.graticule,
    required this.near,
    required this.far,
  });

  final GameState? state;
  final List<Offset> trail;
  final PongSide side;
  final Color graticule;
  final Color near;
  final Color far;

  /// Turns a court position into a screen one, putting this player's wall at
  /// the bottom.
  Offset _project(double x, double y, Size size) => Offset(
    x * size.width,
    (side == PongSide.host ? y : 1 - y) * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    _paintGraticule(canvas, size);
    if (state case final state?) {
      _paintTrail(canvas, size);
      _paintPaddle(canvas, size, state.paddleOf(side), near, isNear: true);
      _paintPaddle(
        canvas,
        size,
        state.paddleOf(side.opponent),
        far,
        isNear: false,
      );
      _paintBall(canvas, size, state);
    }
  }

  void _paintGraticule(Canvas canvas, Size size) {
    final line = Paint()
      ..color = graticule
      ..strokeWidth = 1;

    // The column count is fixed and the rows follow from it, so the cells stay
    // square whatever shape the court ends up: a graticule with rectangular
    // cells reads as a stretched instrument rather than a calibrated one.
    const columns = 8;
    final rows = (columns * size.height / size.width).round().clamp(4, 24);

    for (var column = 1; column < columns; column++) {
      final x = size.width * column / columns;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var row = 1; row < rows; row++) {
      final y = size.height * row / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // The net, drawn heavier than the grid it sits on.
    final net = Paint()
      ..color = graticule
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 7, size.height / 2),
        net,
      );
    }
  }

  /// The phosphor trail: the ball's recent positions, fading behind it.
  void _paintTrail(Canvas canvas, Size size) {
    for (final (index, point) in trail.indexed) {
      final age = (index + 1) / trail.length;
      canvas.drawCircle(
        _project(point.dx, point.dy, size),
        ballRadius * size.width * age,
        Paint()..color = far.withValues(alpha: 0.18 * age * age),
      );
    }
  }

  void _paintPaddle(
    Canvas canvas,
    Size size,
    double centre,
    Color color, {
    required bool isNear,
  }) {
    final width = paddleWidth * size.width;
    final y = isNear
        ? size.height * (1 - paddleInset)
        : size.height * paddleInset;
    final thickness = isNear ? 9.0 : 7.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centre * size.width, y),
          width: width,
          height: thickness,
        ),
        Radius.circular(thickness / 2),
      ),
      Paint()..color = isNear ? color : color.withValues(alpha: 0.55),
    );
  }

  void _paintBall(Canvas canvas, Size size, GameState state) {
    if (!state.rallying) return;
    final centre = _project(state.ballX, state.ballY, size);
    final radius = ballRadius * size.width;
    canvas
      ..drawCircle(
        centre,
        radius * 2.4,
        Paint()..color = far.withValues(alpha: 0.10),
      )
      ..drawCircle(centre, radius, Paint()..color = far);
  }

  @override
  bool shouldRepaint(_CourtPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.near != near ||
      oldDelegate.far != far;
}
