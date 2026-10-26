import 'package:flutter/material.dart';

class AppTheme {
  static const green = Color(0xFF146B45);
  static const greenDark = Color(0xFF0B4F34);
  static const greenLight = Color(0xFFE7F4EC);
  static const gold = Color(0xFFF6D447);
  static const red = Color(0xFFC9363E);
  static const ink = Color(0xFF172B24);
  static const muted = Color(0xFF66766E);
  static const canvas = Color(0xFFF5F7F5);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: green, primary: green, secondary: gold, surface: Colors.white, error: red);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, elevation: 0, centerTitle: false),
      cardTheme: CardTheme(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE7ECE8)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FBF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDCE5DE))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDCE5DE))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: green, side: const BorderSide(color: green), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: greenLight, labelTextStyle: MaterialStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
      chipTheme: ChipThemeData(backgroundColor: greenLight, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
      dividerColor: const Color(0xFFE7ECE8),
    );
  }
}
