import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// نظامُ ألوان تطبيق المندوب — أداةُ عملٍ تُقرأ في الشمس وبيدٍ واحدة.
/// ----------------------------------------------------------------------------
/// قبلها: رأسٌ فيروزيٌّ (`#0F7268`، هويّةٌ سابقة) يأخذ ربعَ كلّ شاشة، ورماديٌّ
/// فاتح `#A8A29E` على أبيض (≈ 2.5:1) لأرقام الطلبات وعناوين الشريط السفليّ.
///
/// الآن:
///   • الحبرُ على الأبيض، والرماديُّ الثانويّ لا ينزل عن 4.7:1.
///   • لونٌ واحدٌ لكلّ معنى، **ثابتٌ في كلّ المطاعم** — كي تتعلّمه اليدُ:
///       نيليّ مؤتمت = ابدأ / تنقّل · أخضر = سُلِّم · أحمر = مشكلة · كهرمانيّ = انتبه.
///     وهويّةُ المطعم (شعارُه واسمُه ولونُه) في الرأس وحدَه.
///   • وضعٌ داكنٌ كامل لمسار المساء.
/// ============================================================================
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryText,
    required this.success,
    required this.onSuccess,
    required this.successSoft,
    required this.successText,
    required this.danger,
    required this.onDanger,
    required this.dangerSoft,
    required this.dangerText,
    required this.warnSoft,
    required this.warnText,
    required this.warnBorder,
  });

  final Color bg, surface, surface2;
  final Color ink, ink2, muted, border, borderStrong;
  final Color primary, onPrimary, primarySoft, primaryText;
  final Color success, onSuccess, successSoft, successText;
  final Color danger, onDanger, dangerSoft, dangerText;
  final Color warnSoft, warnText, warnBorder;

  static const light = Palette(
    bg: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F2F5),
    ink: Color(0xFF0F172A),
    ink2: Color(0xFF334155),
    muted: Color(0xFF5B6475),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    primary: Color(0xFF4F46E5),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEEF2FF),
    primaryText: Color(0xFF3730A3),
    success: Color(0xFF15803D),
    onSuccess: Color(0xFFFFFFFF),
    successSoft: Color(0xFFDCFCE7),
    successText: Color(0xFF166534),
    danger: Color(0xFFB91C1C),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0xFFFEE2E2),
    dangerText: Color(0xFF991B1B),
    warnSoft: Color(0xFFFEF3C7),
    warnText: Color(0xFF78350F),
    warnBorder: Color(0xFFFCD34D),
  );

  static const dark = Palette(
    bg: Color(0xFF0B1120),
    surface: Color(0xFF111827),
    surface2: Color(0xFF1E293B),
    ink: Color(0xFFF1F5F9),
    ink2: Color(0xFFCBD5E1),
    muted: Color(0xFF9AA6B8),
    border: Color(0xFF1F2A3C),
    borderStrong: Color(0xFF334155),
    primary: Color(0xFF4F46E5),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFF1E1B4B),
    primaryText: Color(0xFFA5B4FC),
    success: Color(0xFF15803D),
    onSuccess: Color(0xFFFFFFFF),
    successSoft: Color(0xFF052E16),
    successText: Color(0xFF86EFAC),
    danger: Color(0xFFB91C1C),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0xFF450A0A),
    dangerText: Color(0xFFFCA5A5),
    warnSoft: Color(0xFF3B2405),
    warnText: Color(0xFFFDE68A),
    warnBorder: Color(0xFF854D0E),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

/// اختصارٌ: `context.pal.success`.
extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>() ?? Palette.light;
}

/// أحجامُ الخطّ — لا شيءَ يُقرأ في الطريق تحت ١٣.
class TextSizes {
  TextSizes._();
  static const caption = 13.0;
  static const small = 14.0;
  static const body = 16.0;
  static const bodyLg = 17.0;
  static const title = 20.0;
  static const headline = 24.0;
  static const bag = 30.0;
}

/// [useGoogleFonts] = false في الاختبارات (لا شبكة فيها).
ThemeData buildAppTheme(Brightness brightness, {bool useGoogleFonts = true}) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      surface: p.surface,
      onSurface: p.ink,
      error: p.danger,
    ),
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
  final text = useGoogleFonts
      ? GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
      : base.textTheme;
  return base.copyWith(
    textTheme: text.apply(bodyColor: p.ink, displayColor: p.ink),
    dividerColor: p.border,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primarySoft,
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? p.primaryText : p.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 26,
            color: s.contains(WidgetState.selected) ? p.primaryText : p.muted,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: p.muted, fontSize: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.primary, width: 2)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : null),
    ),
  );
}
