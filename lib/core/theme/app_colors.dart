import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF6C4DFF);
  static const Color secondary = Color(0xFF00B8D9);
  static const Color accent = Color(0xFFFF4D8D);

  static const Color pink = Color(0xFFF0357A);
  static const Color purple = Color(0xFFA23CF0);
  static const Color lavender = Color(0xFFF3EEFF);
  static const Color softPink = Color(0xFFFDE8F1);
  static const Color ink = Color(0xFF1F1147);

  static const Color success = Color(0xFF1FA971);
  static const Color warning = Color(0xFFF5A524);
  static const Color error = Color(0xFFE5484D);

  static const Color lightBackground = Color(0xFFF6F5FF);
  static const Color darkBackground = Color(0xFF0F0D1A);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient adminGradient = LinearGradient(
    colors: [Color(0xFF2B2250), primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [pink, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: [softPink, lavender],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
