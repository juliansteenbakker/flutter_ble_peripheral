/*
 * Copyright (c) 2026. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

// Shared by the flutter_ble_central and flutter_ble_peripheral examples.
// Keep the two copies identical; `tool/sync_example_shell.dart` checks that.

import 'package:flutter/material.dart';

/// Which half of the BLE link an app is.
///
/// The two examples are the same instrument with one hue swapped, so a pair of
/// devices on a desk can be told apart at a glance.
enum DeviceRole {
  /// Scans, connects and subscribes. The flutter_ble_central example.
  central(label: 'CENTRAL', hue: Color(0xFF2E6BE6)),

  /// Advertises and serves a GATT service. The flutter_ble_peripheral example.
  peripheral(label: 'PERIPHERAL', hue: Color(0xFFC8412B));

  const DeviceRole({required this.label, required this.hue});

  /// The name shown in the status rail.
  final String label;

  /// The one accent this app uses. Everything else is neutral.
  final Color hue;
}

/// How good a link is, on the one ramp this app uses for every such judgement.
///
/// The colours do not change between the light and dark themes: an indicator
/// lamp on an instrument means the same thing whatever the light in the room.
enum SignalGrade {
  /// Comfortable. Above -60 dBm.
  strong(Color(0xFF2FBF71)),

  /// Usable. -60 to -75 dBm.
  fair(Color(0xFFE0A526)),

  /// Marginal. -75 to -90 dBm.
  weak(Color(0xFFD2603B)),

  /// Nothing, or not known yet.
  none(Color(0xFF8A8F98));

  const SignalGrade(this.color);

  /// The colour that stands for this grade.
  final Color color;

  /// Grades a received signal strength in dBm.
  static SignalGrade fromRssi(int? rssi) => switch (rssi) {
    null => SignalGrade.none,
    >= -60 => SignalGrade.strong,
    >= -75 => SignalGrade.fair,
    >= -90 => SignalGrade.weak,
    _ => SignalGrade.none,
  };
}

const _uiFamily = 'Archivo';
const _dataFamily = 'IBM Plex Mono';

/// Archivo at an explicit point on its weight (100-900) and width (62-125)
/// axes.
///
/// The file is a variable font, so [FontVariation] rather than [FontWeight] is
/// what actually moves it; the weight is set as well for the platforms that
/// pick a face before the axes are applied.
TextStyle _archivo({
  required double size,
  double weight = 400,
  double width = 100,
  double? tracking,
  double? height,
}) {
  return TextStyle(
    fontFamily: _uiFamily,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
    fontVariations: [
      FontVariation('wght', weight),
      FontVariation('wdth', width),
    ],
    letterSpacing: tracking,
    height: height,
  );
}

/// IBM Plex Mono, for values the radio produced.
TextStyle _mono({
  required double size,
  FontWeight weight = FontWeight.w400,
  double? tracking,
  double? height,
}) {
  return TextStyle(
    fontFamily: _dataFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking,
    height: height,
  );
}

/// The colours and type the instrument shell uses that Material has no slot
/// for.
///
/// Read it with `context.tokens`.
@immutable
final class InstrumentTokens extends ThemeExtension<InstrumentTokens> {
  /// Creates a token set.
  const InstrumentTokens({
    required this.chassis,
    required this.panel,
    required this.ink,
    required this.inkMuted,
    required this.hairline,
    required this.graticule,
    required this.role,
  });

  /// The light token set for [role].
  factory InstrumentTokens.light(DeviceRole role) => InstrumentTokens(
    chassis: const Color(0xFFE8E6E1),
    panel: const Color(0xFFFFFFFF),
    ink: const Color(0xFF14161A),
    inkMuted: const Color(0xFF6B7078),
    hairline: const Color(0xFFD3D0C9),
    graticule: const Color(0xFFDFDCD5),
    role: role,
  );

  /// The dark token set for [role].
  factory InstrumentTokens.dark(DeviceRole role) => InstrumentTokens(
    chassis: const Color(0xFF16181C),
    panel: const Color(0xFF1E2127),
    ink: const Color(0xFFE9EAEC),
    inkMuted: const Color(0xFF8A8F98),
    hairline: const Color(0xFF2C3038),
    graticule: const Color(0xFF262A31),
    role: role,
  );

  /// The colour behind the panels: the instrument's case.
  final Color chassis;

  /// The colour of a panel sitting on the chassis.
  final Color panel;

  /// Text and rules.
  final Color ink;

  /// Text that labels rather than states.
  final Color inkMuted;

  /// The one-pixel rule that separates panels and rows.
  final Color hairline;

  /// The grid behind the pong court and the link meter.
  final Color graticule;

  /// Which half of the link this app is.
  final DeviceRole role;

  /// A stencilled panel label: Archivo at its widest, uppercase and tracked.
  ///
  /// Apply it to text that is already uppercase; it does not transform.
  TextStyle get panelLabel => _archivo(
    size: 11,
    weight: 700,
    width: 125,
    tracking: 1.4,
  ).copyWith(color: inkMuted);

  /// A value the radio produced: dBm, MTU, hex, a count, a score.
  TextStyle get readout => _mono(size: 13, height: 1.35).copyWith(color: ink);

  /// The same, for the one or two values a panel leads with.
  TextStyle get readoutLarge => _mono(
    size: 26,
    weight: FontWeight.w600,
    tracking: -0.5,
  ).copyWith(color: ink);

  /// Hex bytes and uuids, which are read in columns rather than in prose.
  TextStyle get readoutDense =>
      _mono(size: 11, height: 1.5).copyWith(color: inkMuted);

  @override
  InstrumentTokens copyWith({
    Color? chassis,
    Color? panel,
    Color? ink,
    Color? inkMuted,
    Color? hairline,
    Color? graticule,
    DeviceRole? role,
  }) {
    return InstrumentTokens(
      chassis: chassis ?? this.chassis,
      panel: panel ?? this.panel,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      graticule: graticule ?? this.graticule,
      role: role ?? this.role,
    );
  }

  @override
  InstrumentTokens lerp(InstrumentTokens? other, double t) {
    if (other == null) return this;
    return InstrumentTokens(
      chassis: Color.lerp(chassis, other.chassis, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      graticule: Color.lerp(graticule, other.graticule, t)!,
      role: t < 0.5 ? role : other.role,
    );
  }
}

/// Terse access to the shell's tokens and to the values Material does hold.
extension InstrumentContext on BuildContext {
  /// The instrument tokens for the theme in force.
  InstrumentTokens get tokens => Theme.of(this).extension<InstrumentTokens>()!;

  /// The Material colours for the theme in force.
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The Material type scale for the theme in force.
  TextTheme get texts => Theme.of(this).textTheme;

  /// Whether the user asked for less motion. Honour it: the link meter and the
  /// pong court both animate.
  bool get reducedMotion => MediaQuery.disableAnimationsOf(this);
}

/// Builds the theme for [role] at [brightness].
///
/// The Material colour scheme is seeded from the role hue so that the stock
/// widgets land on the same accent, then the surfaces are pinned to the
/// instrument tokens so panels sit on the chassis rather than on a tinted
/// Material surface.
ThemeData instrumentTheme(DeviceRole role, Brightness brightness) {
  final tokens = switch (brightness) {
    Brightness.light => InstrumentTokens.light(role),
    Brightness.dark => InstrumentTokens.dark(role),
  };

  final scheme =
      ColorScheme.fromSeed(
        seedColor: role.hue,
        brightness: brightness,
      ).copyWith(
        primary: role.hue,
        surface: tokens.panel,
        onSurface: tokens.ink,
        onSurfaceVariant: tokens.inkMuted,
        outlineVariant: tokens.hairline,
        error: SignalGrade.weak.color,
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.chassis,
    extensions: [tokens],
    textTheme: _textTheme(tokens),
    dividerTheme: DividerThemeData(
      color: tokens.hairline,
      space: 1,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: _archivo(size: 13, weight: 600, tracking: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        side: BorderSide(color: tokens.hairline),
        foregroundColor: tokens.ink,
        textStyle: _archivo(size: 13, weight: 600, tracking: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: tokens.chassis,
      hintStyle: _mono(size: 13).copyWith(color: tokens.inkMuted),
      labelStyle: tokens.panelLabel,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: tokens.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: tokens.hairline),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? role.hue : tokens.inkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? role.hue.withValues(alpha: 0.28)
            : tokens.chassis,
      ),
      trackOutlineColor: WidgetStatePropertyAll(tokens.hairline),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: tokens.panel,
        foregroundColor: tokens.inkMuted,
        selectedBackgroundColor: role.hue.withValues(alpha: 0.14),
        selectedForegroundColor: role.hue,
        side: BorderSide(color: tokens.hairline),
        textStyle: _archivo(size: 13, weight: 600),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: role.hue.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(tokens.panelLabel),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 20,
          color: states.contains(WidgetState.selected)
              ? role.hue
              : tokens.inkMuted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorColor: role.hue.withValues(alpha: 0.16),
      selectedLabelTextStyle: tokens.panelLabel.copyWith(color: role.hue),
      unselectedLabelTextStyle: tokens.panelLabel,
      selectedIconTheme: IconThemeData(size: 20, color: role.hue),
      unselectedIconTheme: IconThemeData(size: 20, color: tokens.inkMuted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.ink,
      contentTextStyle: _archivo(size: 13).copyWith(color: tokens.chassis),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
  );
}

TextTheme _textTheme(InstrumentTokens tokens) {
  final ink = tokens.ink;
  final muted = tokens.inkMuted;
  return TextTheme(
    // Reserved for the few places a panel leads with a word rather than a
    // value, such as a device name.
    titleLarge: _archivo(size: 20, weight: 600, tracking: -0.2).copyWith(
      color: ink,
    ),
    titleMedium: _archivo(size: 15, weight: 600).copyWith(color: ink),
    bodyMedium: _archivo(size: 14, height: 1.45).copyWith(color: ink),
    bodySmall: _archivo(size: 12.5, height: 1.4).copyWith(color: muted),
    labelLarge: _archivo(size: 13, weight: 600, tracking: 0.2).copyWith(
      color: ink,
    ),
    labelSmall: tokens.panelLabel,
  );
}
