import 'package:flutter/material.dart';

/// شعار «مؤتمت» — العلامة الشبكيّة من عُدّة الهوية (`svg/mark-indigo.svg`).
///
/// المربّعات بإحداثياتها كما في الملف المتّجه (viewBox 100×90) لا مرسومةً
/// بالتقدير: شعارٌ «يشبه» الشعار ليس الشعار، والفرق يظهر أوّل ما يوضع بجانب
/// المطبوعات من العُدّة نفسها.
///
/// حرف M شبكيّ: عمودان كاملان على الطرفين، وقمّتان باهتتان (٣٠٪) تصنعان
/// الانحدار، ونقطةُ حبرٍ في القلب هي العقدة الوحيدة غير النيليّة.
///
/// (كان قبله حلقةً تركوازية `#2DD4BF` — من الهوية السابقة.)
class MoaatmatLogo extends StatelessWidget {
  const MoaatmatLogo({
    super.key,
    this.size = 20,
    this.accent = brandIndigo,
    this.dot,
  });

  /// نيليّ مؤتمت — من دليل الأصول.
  static const brandIndigo = Color(0xFF4F46E5);

  /// حبر الهوية — لون العقدة الوسطى.
  static const brandInk = Color(0xFF16161A);

  final double size;
  final Color accent;

  /// لون العقدة الوسطى. الافتراضي حبر الهوية، ويُمرَّر أبيضَ على خلفيةٍ داكنة.
  final Color? dot;

  // [x, y] بمقياس الملف المتّجه — والمربّع 16×16 بنصف قطر 5.
  static const _cells = [
    [4.0, 4.0], [4.0, 26.0], [4.0, 48.0], [4.0, 70.0],
    [26.0, 26.0], [58.0, 26.0],
    [80.0, 4.0], [80.0, 26.0], [80.0, 48.0], [80.0, 70.0],
  ];
  static const _faint = [
    [26.0, 4.0],
    [58.0, 4.0],
  ];

  @override
  Widget build(BuildContext context) {
    // الارتفاع يتبع نسبة الشعار (90/100): تمرير `size` للبُعدين يسحقه.
    return CustomPaint(
      size: Size(size, size * 90 / 100),
      painter: _GridMarkPainter(accent: accent, dot: dot ?? brandInk),
    );
  }
}

class _GridMarkPainter extends CustomPainter {
  _GridMarkPainter({required this.accent, required this.dot});

  final Color accent;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100; // معامل التحجيم من مقياس الملف المتّجه
    final r = Radius.circular(5 * k);

    void cell(double x, double y, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x * k, y * k, 16 * k, 16 * k), r),
        Paint()..color = c,
      );
    }

    for (final p in MoaatmatLogo._cells) {
      cell(p[0], p[1], accent);
    }
    for (final p in MoaatmatLogo._faint) {
      cell(p[0], p[1], accent.withValues(alpha: 0.3));
    }
    cell(42, 48, dot); // العقدة الوسطى
  }

  @override
  bool shouldRepaint(covariant _GridMarkPainter old) =>
      old.accent != accent || old.dot != dot;
}
