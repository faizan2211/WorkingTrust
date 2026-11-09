import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B4F4F);
  static const Color primaryDark = Color(0xFF073838);
  static const Color primaryLight = Color(0xFF1A7A7A);

  static const Color secondary = Color(0xFF34A853);
  static const Color accent = Color(0xFFC8E6B8);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  static const Color success = Color(0xFF34A853);
  static const Color error = Color(0xFFEA4335);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF1A73E8);

  static const Color shadow = Color(0x1A000000);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
