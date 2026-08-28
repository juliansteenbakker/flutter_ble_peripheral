/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.
// ignore_for_file: always_use_package_imports

import 'package:flutter/material.dart';

import '../shell/theme.dart';
import 'game.dart';
import 'protocol.dart';

/// The scores, the serve button and one line of status.
///
/// Deliberately a strip rather than a panel: on a phone every row here is a
/// row the court does not get, and the court is the point.
class PongScoreBar extends StatelessWidget {
  /// Creates a score bar for [player].
  const PongScoreBar({
    required this.player,
    required this.onStart,
    required this.status,
    super.key,
  });

  /// The end being scored.
  final PongPlayer player;

  /// Starts, or restarts, a game.
  final VoidCallback onStart;

  /// Builds the line under the scores. Called with the state on screen.
  final String Function(GameState? state) status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final state = player.state;
        final rallying = state?.rallying ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Row(
              spacing: 16,
              children: [
                _Score(
                  label: 'YOU',
                  value: state?.scoreOf(player.side) ?? 0,
                  tint: tokens.role.hue,
                ),
                _Score(
                  label: 'THEM',
                  value: state?.scoreOf(player.side.opponent) ?? 0,
                  tint: tokens.ink,
                ),
                const Spacer(),
                if (player.roundTrip case final trip?)
                  Text('${trip.inMilliseconds} ms', style: tokens.readoutDense),
                FilledButton(
                  onPressed: onStart,
                  child: Text(rallying ? 'Restart' : 'Serve'),
                ),
              ],
            ),
            Text(
              status(state),
              style: context.texts.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.label, required this.value, required this.tint});

  final String label;
  final int value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: tokens.panelLabel),
        Text('$value', style: tokens.readoutLarge.copyWith(color: tint)),
      ],
    );
  }
}
