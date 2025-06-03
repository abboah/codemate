import 'package:flutter/material.dart';

@immutable
class DarkGradientColors extends ThemeExtension<DarkGradientColors> {
  final Color black;
  final Color dark1;
  final Color dark2;

  const DarkGradientColors({
    required this.black,
    required this.dark1,
    required this.dark2,
  });

  @override
  DarkGradientColors copyWith({Color? black, Color? dark1, Color? dark2}) {
    return DarkGradientColors(
      black: black ?? this.black,
      dark1: dark1 ?? this.dark1,
      dark2: dark2 ?? this.dark2,
    );
  }

  @override
  DarkGradientColors lerp(ThemeExtension<DarkGradientColors>? other, double t) {
    if (other is! DarkGradientColors) return this;
    return DarkGradientColors(
      black: Color.lerp(black, other.black, t)!,
      dark1: Color.lerp(dark1, other.dark1, t)!,
      dark2: Color.lerp(dark2, other.dark2, t)!,
    );
  }
}
