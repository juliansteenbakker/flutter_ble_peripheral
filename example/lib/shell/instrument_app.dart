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

import 'link_meter.dart';
import 'panel.dart';
import 'theme.dart';

/// The width at or above which the navigation moves to the side and the app
/// stops being a phone.
const _wideLayout = 720.0;

/// The root of both example apps.
///
/// It carries nothing of its own: the role picks the accent, and everything
/// else arrives from the app that built it.
class InstrumentApp extends StatelessWidget {
  /// Creates the app shell for [role].
  const InstrumentApp({required this.role, required this.home, super.key});

  /// Which half of the link this app is.
  final DeviceRole role;

  /// The screen under the shell, which is the app's own widget.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:
          '${role.label[0]}${role.label.substring(1).toLowerCase()} '
          'instrument',
      debugShowCheckedModeBanner: false,
      theme: instrumentTheme(role, Brightness.light),
      darkTheme: instrumentTheme(role, Brightness.dark),
      home: home,
    );
  }
}

/// One of the four places an example app can be.
///
/// Both apps carry the same four, in the same order, so someone who learns one
/// already knows the other.
@immutable
final class Destination {
  /// Creates a destination.
  const Destination({
    required this.label,
    required this.icon,
    required this.builder,
  });

  /// The word in the navigation.
  final String label;

  /// The glyph beside it.
  final IconData icon;

  /// Builds the page. Called only while the destination is selected.
  final WidgetBuilder builder;
}

/// The instrument face: a status rail that never scrolls, and the selected
/// page under it.
class InstrumentScaffold extends StatefulWidget {
  /// Creates the face.
  const InstrumentScaffold({
    required this.telemetry,
    required this.adapterState,
    required this.adapterGrade,
    required this.linked,
    required this.destinations,
    super.key,
  });

  /// What the link meter plots.
  final LinkTelemetry telemetry;

  /// The adapter's position in its state machine, named as the plugin names
  /// it.
  final String adapterState;

  /// How healthy that state is.
  final SignalGrade adapterGrade;

  /// Whether a link is up. Its arrival is the one moment the shell animates.
  final bool linked;

  /// The pages, in order.
  final List<Destination> destinations;

  @override
  State<InstrumentScaffold> createState() => _InstrumentScaffoldState();
}

class _InstrumentScaffoldState extends State<InstrumentScaffold>
    with SingleTickerProviderStateMixin {
  late final _flood = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  var _selected = 0;

  @override
  void didUpdateWidget(InstrumentScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.linked && !oldWidget.linked && !context.reducedMotion) {
      _flood.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flood.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
    final page = KeyedSubtree(
      key: ValueKey(_selected),
      child: Builder(builder: widget.destinations[_selected].builder),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StatusRail(
              telemetry: widget.telemetry,
              adapterState: widget.adapterState,
              adapterGrade: widget.adapterGrade,
              flood: _flood,
            ),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        _SideNav(
                          destinations: widget.destinations,
                          selected: _selected,
                          onSelected: _select,
                        ),
                        Expanded(child: page),
                      ],
                    )
                  : page,
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : _BottomNav(
              destinations: widget.destinations,
              selected: _selected,
              onSelected: _select,
            ),
    );
  }

  void _select(int index) => setState(() => _selected = index);
}

/// The readout across the top: who this device is, what its radio is doing,
/// and the meter.
class _StatusRail extends StatelessWidget {
  const _StatusRail({
    required this.telemetry,
    required this.adapterState,
    required this.adapterGrade,
    required this.flood,
  });

  final LinkTelemetry telemetry;
  final String adapterState;
  final SignalGrade adapterGrade;
  final Animation<double> flood;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final role = tokens.role;

    return AnimatedBuilder(
      animation: flood,
      builder: (context, child) {
        // One swell of the role hue when a link comes up, then gone.
        final wash = Curves.easeOutCubic.transform(flood.value);
        return ColoredBox(
          color: Color.lerp(
            tokens.chassis,
            role.hue,
            (wash < 0.5 ? wash : 1 - wash) * 0.36,
          )!,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 10,
              children: [
                Lamp(color: role.hue),
                Text(
                  role.label,
                  style: tokens.panelLabel.copyWith(color: role.hue),
                ),
                const Spacer(),
                StateChip(label: adapterState, grade: adapterGrade),
              ],
            ),
            ListenableBuilder(
              listenable: telemetry,
              child: LinkMeter(telemetry: telemetry),
              builder: (context, meter) => Semantics(
                label: 'Link meter',
                value: telemetry.caption,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 6,
                  children: [
                    meter!,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            telemetry.caption,
                            style: tokens.readoutDense,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _PacketCount(telemetry: telemetry),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two running totals, in the same colours the meter's raster uses.
class _PacketCount extends StatelessWidget {
  const _PacketCount({required this.telemetry});

  final LinkTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      spacing: 10,
      children: [
        Text(
          '↑ ${telemetry.outbound}',
          style: tokens.readoutDense.copyWith(color: tokens.role.hue),
        ),
        Text('↓ ${telemetry.inbound}', style: tokens.readoutDense),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<Destination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: selected,
        onDestinationSelected: onSelected,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<Destination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(right: BorderSide(color: tokens.hairline)),
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: selected,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (final destination in destinations)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              label: Text(destination.label),
            ),
        ],
      ),
    );
  }
}
