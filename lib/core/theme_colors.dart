import 'package:flutter/material.dart';

/// Central color source (no hard-coded colors anywhere else).
/// Add warm mode later by extending AppPalette.
class AppPalette {
  final Color bg;          
  final Color primary;     
  final Color onPrimary;   
  final Color text;        
  final Color textMuted;   
  final Color stroke;      
  final Color accent;      
  final Color icon;
  final Color bgOff;
  final Color newPrimary;
  final Color newOnPrimary;
  final Color secondary;

  const AppPalette({
    required this.bg,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.textMuted,
    required this.stroke,
    required this.accent,
    required this.icon,
    required this.bgOff,
    required this.newPrimary,
    required this.newOnPrimary,
    required this.secondary,

  });

  /// LIGHT COOL
  factory AppPalette.light() => const AppPalette(
        bg: Color.fromARGB(255, 0, 0, 0),
        primary: Color.fromARGB(255, 58, 101, 255),
        onPrimary: Color.fromARGB(255, 129, 203, 246),
        text: Color.fromARGB(255, 254, 253, 255),
        textMuted: Color.fromARGB(255, 171, 171, 171),
        stroke: Color.fromARGB(168, 242, 242, 244),
        accent: Color.fromARGB(255, 15, 0, 128),
        icon: Color.fromARGB(255, 255, 255, 255),
        bgOff: Color.fromARGB(255, 26, 21, 32),
        newPrimary:Color.fromARGB(255, 255, 58, 58),
        newOnPrimary:Color.fromARGB(255, 255, 140, 140),
        secondary:Color.fromARGB(255, 26, 200, 16),
      );

  
}

/// Theme extension so we can read colors anywhere via:
/// `context.appColors`.
class AppColors extends ThemeExtension<AppColors> {
  final AppPalette palette;
  const AppColors(this.palette);

  @override
  AppColors copyWith({AppPalette? palette}) =>
      AppColors(palette ?? this.palette);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    // Simple switch—no morphing needed.
    return t < 0.5 ? this : other;
  }
}

extension AppColorX on BuildContext {
  AppPalette get appColors =>
      Theme.of(this).extension<AppColors>()!.palette;
}
