/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// The imports below are relative for that reason: a package import would name
// one example or the other and the file could no longer be shared verbatim.
// ignore_for_file: always_use_package_imports

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Which way a packet went.
enum PacketDirection {
  /// The radio received it: a notification here, a write on the peripheral.
  inbound,

  /// This app sent it: a write here, a notification from the peripheral.
  outbound,
}

/// What the apps hand [LinkMeter]: how good the link is now, and a running
/// count of the packets that have crossed it.
///
/// The counts are cumulative and never reset. The meter differentiates them
/// into a rate itself, so an app only has to say that a packet happened.
final class LinkTelemetry extends ChangeNotifier {
  SignalGrade _grade = SignalGrade.none;
  double? _level;
  String _caption = 'idle';
  int _inbound = 0;
  int _outbound = 0;
  bool _pending = false;
  bool _disposed = false;

  /// How good the link is.
  SignalGrade get grade => _grade;

  /// Where the trace sits, from 0 at the floor to 1 at the ceiling, or null
  /// when there is nothing to plot.
  double? get level => _level;

  /// The line beside the meter, in the units of whatever it is plotting.
  String get caption => _caption;

  /// Packets received since the app started.
  int get inbound => _inbound;

  /// Packets sent since the app started.
  int get outbound => _outbound;

  /// States the current quality of the link.
  ///
  /// [caption] carries the units, since the meter is deliberately unlabelled:
  /// it plots dBm while scanning and round-trip milliseconds during a game.
  void report({
    required SignalGrade grade,
    required String caption,
    double? level,
  }) {
    if (grade == _grade && caption == _caption && level == _level) return;
    _grade = grade;
    _caption = caption;
    _level = level;
    _notify();
  }

  /// Counts [count] packets that went [direction].
  void count(PacketDirection direction, [int count = 1]) {
    switch (direction) {
      case PacketDirection.inbound:
        _inbound += count;
      case PacketDirection.outbound:
        _outbound += count;
    }
    _notify();
  }

  /// Drops the trace back to idle, keeping the counts.
  void clear() => report(grade: SignalGrade.none, caption: 'idle');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notifies, waiting for the end of the frame if the tree is locked.
  ///
  /// A page reports from its own `dispose`, which runs while the framework is
  /// finalizing the tree and nothing may be marked dirty. The meter and the
  /// readout beside it listen from above that page, so the report has to wait
  /// for the frame to end.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_pending) return;
    _pending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!_disposed) notifyListeners();
    });
  }
}

/// The one bold element in the shell: a live plot of the radio link.
///
/// Idle it is flat. Connected it plots whatever the app is measuring, and
/// every packet that crosses the link raises a tick along the top edge, so the
/// strip is the ATT traffic rather than a decoration of it.
class LinkMeter extends StatefulWidget {
  /// Creates a meter reading from [telemetry].
  const LinkMeter({required this.telemetry, this.height = 34, super.key});

  /// What to plot. The meter does not own it; the app does.
  final LinkTelemetry telemetry;

  /// How tall the strip is.
  final double height;

  @override
  State<LinkMeter> createState() => _LinkMeterState();
}

class _LinkMeterState extends State<LinkMeter>
    with SingleTickerProviderStateMixin {
  /// How many columns the strip holds. At the sample interval below this is
  /// about twelve seconds of history.
  static const _columns = 120;
  static const _interval = Duration(milliseconds: 100);

  final List<_Sample> _trace = List.filled(_columns, const _Sample.empty());
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_onTick);

  int _head = 0;
  Duration _lastSample = Duration.zero;
  int _lastInbound = 0;
  int _lastOutbound = 0;

  @override
  void initState() {
    super.initState();
    widget.telemetry.addListener(_onReport);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A user who asked for less motion gets the trace as it stands, updated
    // when the link changes, rather than a strip that scrolls forever.
    if (context.reducedMotion) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(LinkMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.telemetry != widget.telemetry) {
      oldWidget.telemetry.removeListener(_onReport);
      widget.telemetry.addListener(_onReport);
    }
  }

  @override
  void dispose() {
    widget.telemetry.removeListener(_onReport);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onReport() => _repaint.value++;

  void _onTick(Duration elapsed) {
    if (elapsed - _lastSample < _interval) return;
    _lastSample = elapsed;

    final telemetry = widget.telemetry;
    final inbound = telemetry.inbound - _lastInbound;
    final outbound = telemetry.outbound - _lastOutbound;
    _lastInbound = telemetry.inbound;
    _lastOutbound = telemetry.outbound;

    _trace[_head] = _Sample(
      level: telemetry.level,
      grade: telemetry.grade,
      inbound: inbound,
      outbound: outbound,
    );
    _head = (_head + 1) % _columns;
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: widget.height,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LinkMeterPainter(
            repaint: _repaint,
            trace: _trace,
            head: () => _head,
            graticule: tokens.graticule,
            outbound: tokens.role.hue,
            inbound: tokens.ink,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

@immutable
class _Sample {
  const _Sample({
    required this.level,
    required this.grade,
    required this.inbound,
    required this.outbound,
  });

  const _Sample.empty()
    : level = null,
      grade = SignalGrade.none,
      inbound = 0,
      outbound = 0;

  final double? level;
  final SignalGrade grade;
  final int inbound;
  final int outbound;
}

class _LinkMeterPainter extends CustomPainter {
  _LinkMeterPainter({
    required this.trace,
    required this.head,
    required this.graticule,
    required this.outbound,
    required this.inbound,
    required super.repaint,
  });

  /// Packets in one 100 ms column that count as a full-height tick. Twenty a
  /// second is what the pong host sends, so a game reads as a solid band.
  static const _busyColumn = 4;

  final List<_Sample> trace;

  /// Read at paint time rather than captured, since the strip advances without
  /// the widget rebuilding.
  final int Function() head;
  final Color graticule;
  final Color outbound;
  final Color inbound;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = trace.length;
    final head = this.head();
    final columnWidth = size.width / columns;
    final rasterHeight = size.height * 0.22;
    final floor = size.height;
    final ceiling = rasterHeight + 2;

    final grid = Paint()
      ..color = graticule
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += size.width / 8) {
      canvas.drawLine(Offset(x, ceiling), Offset(x, floor), grid);
    }
    canvas.drawLine(
      Offset(0, (ceiling + floor) / 2),
      Offset(size.width, (ceiling + floor) / 2),
      grid,
    );

    // The trace, oldest at the left. `head` is where the next sample lands, so
    // it is also the oldest column.
    // A column with nothing to plot sits on the floor rather than going
    // missing, so an idle meter reads as an instrument at rest.
    final path = Path();
    final fill = Path()..moveTo(0, floor);
    var traceColor = SignalGrade.none.color;

    for (var column = 0; column < columns; column++) {
      final sample = trace[(head + column) % columns];
      final x = column * columnWidth;
      final level = sample.level ?? 0;
      final y = floor - (floor - ceiling) * level.clamp(0.0, 1.0);

      if (sample.level != null) traceColor = sample.grade.color;
      if (column == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      fill.lineTo(x, y);

      _paintTicks(canvas, sample, x, columnWidth, rasterHeight);
    }
    fill
      ..lineTo(size.width, floor)
      ..close();

    canvas
      ..drawPath(fill, Paint()..color = traceColor.withValues(alpha: 0.16))
      ..drawPath(
        path,
        Paint()
          ..color = traceColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
  }

  /// One column of the event raster: outbound above the rule, inbound below.
  void _paintTicks(
    Canvas canvas,
    _Sample sample,
    double x,
    double columnWidth,
    double rasterHeight,
  ) {
    if (sample.inbound == 0 && sample.outbound == 0) return;
    final lane = rasterHeight / 2 - 1;
    final width = (columnWidth - 0.5).clamp(0.5, 3.0);

    // Outbound hangs up from the rule, inbound down from it, so a one-sided
    // conversation is obvious at a glance.
    void tick(int packets, Color color, {required bool downward}) {
      if (packets == 0) return;
      final height = lane * (packets / _busyColumn).clamp(0.35, 1.0);
      final top = downward ? lane + 2 : lane - height;
      canvas.drawRect(
        Rect.fromLTWH(x, top, width, height),
        Paint()..color = color,
      );
    }

    tick(sample.outbound, outbound, downward: false);
    tick(sample.inbound, inbound.withValues(alpha: 0.55), downward: true);
  }

  @override
  bool shouldRepaint(_LinkMeterPainter oldDelegate) => true;
}
