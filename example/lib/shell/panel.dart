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

import 'theme.dart';

/// A section of the instrument face: a hairline box under a stencilled label.
///
/// Panels do not float. They sit flush on the chassis, so there is no
/// elevation and no shadow anywhere in the shell.
class Panel extends StatelessWidget {
  /// Creates a panel labelled [label].
  const Panel({
    required this.label,
    required this.children,
    this.trailing,
    this.footnote,
    super.key,
  });

  /// The stencilled label. Written in whatever case it should appear in.
  final String label;

  /// The contents, laid out in a column with the panel's own gutter between
  /// them.
  final List<Widget> children;

  /// A control that belongs to the panel as a whole, shown beside [label].
  final Widget? trailing;

  /// A line under the contents for what the panel cannot say in its readouts,
  /// such as why a control is disabled on this platform.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // A Material rather than a DecoratedBox: panels hold ink wells and list
    // tiles, and both paint their splashes onto the nearest Material.
    return Material(
      color: tokens.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.hairline),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(child: Text(label, style: tokens.panelLabel)),
                ?trailing,
              ],
            ),
          ),
          Divider(color: tokens.hairline),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: children,
            ),
          ),
          if (footnote case final footnote?) ...[
            Divider(color: tokens.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(footnote, style: context.texts.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

/// A label above a value the radio produced.
///
/// The label is stencilled and the value is mono, which is the rule the whole
/// shell follows: words the app chose are Archivo, numbers the radio produced
/// are Plex Mono.
class Readout extends StatelessWidget {
  /// Creates a readout of [value] under [label].
  const Readout({
    required this.label,
    required this.value,
    this.tint,
    this.large = false,
    super.key,
  });

  /// What the value is.
  final String label;

  /// The value. Pass a placeholder rather than an empty string when there is
  /// nothing yet, so the panel does not change height when one arrives.
  final String value;

  /// Colours the value, for the readouts that carry a [SignalGrade].
  final Color? tint;

  /// Whether this is a value the panel leads with.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = large ? tokens.readoutLarge : tokens.readout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tokens.panelLabel),
        const SizedBox(height: 2),
        Text(
          value,
          style: tint == null ? style : style.copyWith(color: tint),
        ),
      ],
    );
  }
}

/// A row of [Readout]s that share a panel, each taking an equal share.
class ReadoutRow extends StatelessWidget {
  /// Creates a row of [readouts].
  const ReadoutRow(this.readouts, {super.key});

  /// The readouts, left to right.
  final List<Readout> readouts;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final readout in readouts) Expanded(child: readout),
      ],
    );
  }
}

/// A tappable row: what it does, what that means, and whether it can be done
/// here.
///
/// A call the platform does not serve is shown greyed with its
/// [unavailable] reason rather than hidden, so the example doubles as the
/// support matrix.
class ActionRow extends StatelessWidget {
  /// Creates a row that runs [onTap].
  const ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.unavailable,
    super.key,
  });

  /// The glyph in the gutter.
  final IconData icon;

  /// What the row does, as a verb the user recognises.
  final String title;

  /// What happens when it runs.
  final String? subtitle;

  /// Runs when the row is tapped.
  final VoidCallback onTap;

  /// Why this cannot run here, or null when it can.
  final String? unavailable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final blocked = unavailable != null;
    final foreground = blocked ? tokens.inkMuted : tokens.ink;

    return Semantics(
      button: true,
      enabled: !blocked,
      child: InkWell(
        onTap: blocked ? null : onTap,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            spacing: 12,
            children: [
              Icon(icon, size: 20, color: blocked ? tokens.inkMuted : null),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.texts.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                    if (unavailable case final reason?)
                      Text(reason, style: context.texts.bodySmall)
                    else if (subtitle case final subtitle?)
                      Text(subtitle, style: context.texts.bodySmall),
                  ],
                ),
              ),
              if (!blocked)
                Icon(Icons.chevron_right, size: 18, color: tokens.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lamp and a word: the shell's way of stating a state machine's position.
class StateChip extends StatelessWidget {
  /// Creates a chip showing [label] lit in [grade].
  const StateChip({
    required this.label,
    required this.grade,
    this.pulsing = false,
    super.key,
  });

  /// The state, written the way the plugin's enum writes it.
  final String label;

  /// How healthy that state is.
  final SignalGrade grade;

  /// Whether the lamp should breathe, for a state that is in progress.
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Lamp(color: grade.color, pulsing: pulsing),
        Text(label, style: context.tokens.readout),
      ],
    );
  }
}

/// An indicator lamp: the shell's only decoration, and it always means
/// something.
class Lamp extends StatefulWidget {
  /// Creates a lamp lit in [color].
  const Lamp({required this.color, this.pulsing = false, super.key});

  /// What it is lit in, which is a [SignalGrade] colour or a role hue.
  final Color color;

  /// Whether it should breathe, for a state that is still in progress.
  final bool pulsing;

  @override
  State<Lamp> createState() => _LampState();
}

class _LampState extends State<Lamp> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Both the pulsing flag and the reduced-motion setting can change under the
  // lamp, and neither is readable before dependencies are in place.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Lamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.pulsing && !context.reducedMotion) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.35, end: 1)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// A numbered instruction, used by the permission and adapter dialogs.
///
/// The numbers are load-bearing: these are ordered steps someone follows in a
/// system settings app, not a decorated list.
class StepList extends StatelessWidget {
  /// Creates a list of [steps], numbered from one.
  const StepList(this.steps, {super.key});

  /// The steps, in the order they must be done.
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final (index, step) in steps.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text('${index + 1}'.padLeft(2, '0'), style: tokens.readoutDense),
              Expanded(child: Text(step, style: context.texts.bodyMedium)),
            ],
          ),
      ],
    );
  }
}
