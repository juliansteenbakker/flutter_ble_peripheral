/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral_example/pages/data_page.dart';
import 'package:flutter_ble_peripheral_example/pages/link_page.dart';
import 'package:flutter_ble_peripheral_example/pages/pong_page.dart';
import 'package:flutter_ble_peripheral_example/pages/setup_page.dart';
import 'package:flutter_ble_peripheral_example/peripheral_controller.dart';
import 'package:flutter_ble_peripheral_example/shell/shell.dart';

/// The peripheral example: one controller, four pages over it.
class PeripheralHome extends StatefulWidget {
  /// Creates the app.
  const PeripheralHome({super.key});

  @override
  State<PeripheralHome> createState() => _PeripheralHomeState();
}

class _PeripheralHomeState extends State<PeripheralHome> {
  final _controller = PeripheralController();

  @override
  void initState() {
    super.initState();
    _controller.notice.addListener(_showNotice);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ensureRadioReady(context, _controller);
      await _controller.refreshState();
    });
  }

  @override
  void dispose() {
    _controller
      ..notice.removeListener(_showNotice)
      ..dispose();
    super.dispose();
  }

  void _showNotice() {
    if (_controller.notice.value case final notice? when mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(notice.message),
            backgroundColor: notice.isError ? SignalGrade.weak.color : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => InstrumentScaffold(
        telemetry: _controller.telemetry,
        adapterState: _controller.state.name,
        adapterGrade: _controller.state.grade,
        linked: _controller.isSubscribed,
        destinations: [
          Destination(
            label: 'Link',
            icon: Icons.settings_input_antenna,
            builder: (_) => LinkPage(controller: _controller),
          ),
          Destination(
            label: 'Data',
            icon: Icons.swap_vert,
            builder: (_) => DataPage(controller: _controller),
          ),
          Destination(
            label: 'Pong',
            icon: Icons.sports_tennis,
            builder: (_) => PongPage(controller: _controller),
          ),
          Destination(
            label: 'Setup',
            icon: Icons.tune,
            builder: (_) => SetupPage(controller: _controller),
          ),
        ],
      ),
    );
  }
}
