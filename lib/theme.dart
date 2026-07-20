import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان تطبيق المندوب — منقولة حرفياً من التصميم المعتمد (رأس تركوازي).
class AppColors {
  AppColors._();

  static const teal = Color(0xFF0F7268);
  static const tealDark = Color(0xFF0B564F);
  static const tealTint = Color(0xFFE6F2F0);
  static const tealTint2 = Color(0xFFF4F7F6);

  static const ink = Color(0xFF1C1C1A);
  static const inkBlack = Color(0xFF141513);
  static const muted = Color(0xFF78716C);
  static const muted2 = Color(0xFF57534E);
  static const muted3 = Color(0xFFA8A29E);

  static const border = Color(0xFFECECEA);
  static const border2 = Color(0xFFF0EFEC);

  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFFBFBFA);
  static const surface3 = Color(0xFFF6F5F3);
  static const canvas = Color(0xFFE8E6E1);

  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFBF1E4);
  static const danger = Color(0xFFC0392B);
  static const dangerBg = Color(0xFFFDF3F2);
  static const dangerBorder = Color(0xFFF5DCD8);
}

/// ثيم فاتح عربي RTL بخط IBM Plex Sans Arabic.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
  );
  return base.copyWith(
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    splashColor: AppColors.tealTint,
    highlightColor: Colors.transparent,
  );
}
