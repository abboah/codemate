import 'package:codemate/themes/dark_theme_extension.dart';
import 'package:flutter/material.dart';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF000000),
  extensions: const <ThemeExtension<dynamic>>[
    DarkGradientColors(
      black: Color(0xFF000000),
      dark1: Color(0xFF0A0A0F),
      dark2: Color(0xFF111118),
    ),
  ],
  cardColor: const Color(0xFF0A0A0F),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF1E90FF),
    secondary: Color(0xFF6C5DD3),
    background: Color(0xFF000000),
    surface: Color(0xFF111118),
    onPrimary: Color(0xFFECECEC),
    onSecondary: Color(0xFFAAAAAA),
    onBackground: Color(0xFFECECEC),
    onSurface: Color(0xFFECECEC),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFECECEC)),
    bodyMedium: TextStyle(color: Color(0xFFAAAAAA)),
  ),
);
