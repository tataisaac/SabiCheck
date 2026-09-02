import 'package:flutter/material.dart';

import '../models/scam_analysis.dart';

/// SabiCheck visual language — emerald/teal brand carried over from the web app
/// (Tailwind emerald-500 #10B981 / slate neutrals), expressed as Material 3.
class AppTheme {
  AppTheme._();

  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF34D399);
  static const Color teal = Color(0xFF14B8A6);

  // Risk palette (matches the web badges: emerald / amber / red).
  static const Color riskLow = Color(0xFF059669);
  static const Color riskMedium = Color(0xFFD97706);
  static const Color riskHigh = Color(0xFFDC2626);

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.light,
      primary: emerald,
      surface: Colors.white,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: slate50,
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: slate200),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.dark,
      primary: emeraldDark,
      surface: slate900,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: slate950,
      cardTheme: const CardThemeData(
        color: slate900,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: slate800),
        ),
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static Color riskColor(RiskLevel level) => switch (level) {
        RiskLevel.low => riskLow,
        RiskLevel.medium => riskMedium,
        RiskLevel.high => riskHigh,
      };

  static IconData riskIcon(RiskLevel level) => switch (level) {
        RiskLevel.low => Icons.check_circle_rounded,
        RiskLevel.medium => Icons.warning_amber_rounded,
        RiskLevel.high => Icons.gpp_bad_rounded,
      };
}
