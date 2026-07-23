import 'dart:math' as math;

import 'package:flutter/material.dart';

/// شعار «مؤتمت» (حلقة الأتمتة): قوسان يدوران حول المركز ونقطتان (مدخل/مخرج).
/// مرسوم عبر CustomPaint دون أي حزم إضافية. يتكيّف مع الوضع الفاتح/الداكن.
class MoaatmatLogo extends StatelessWidget {
  const MoaatmatLogo({
    super.key,
    this.size = 20,
    this.accent = const Color(0xFF2DD4BF),
    this.ring,
    this.dot,
  });

  final double size;
  final Color accent;
  final Color? ring;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MoaatmatPainter(
        accent: accent,
        ring: ring ?? Theme.of(context).dividerColor,
        dot: dot ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _MoaatmatPainter extends CustomPainter {
  _MoaatmatPainter({required this.accent, required this.ring, required this.dot});

  final Color accent;
  final Color ring;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final r = s * 30 / 76; // نصف القطر بمقياس viewBox الأصلي (76)
    final sw = s * 8 / 76; // سماكة الخط
    final dotR = s * 7 / 76;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..color = ring;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..color = accent;

    canvas.drawCircle(center, r, ringPaint);

    final rect = Rect.fromCircle(center: center, radius: r);
    const quarter = math.pi / 2;
    canvas.drawArc(rect, -quarter, quarter, false, arcPaint); // أعلى ← يمين
    canvas.drawArc(rect, quarter, quarter, false, arcPaint); // أسفل ← يسار

    final dotPaint = Paint()..color = dot;
    canvas.drawCircle(Offset(center.dx, s * 8 / 76), dotR, dotPaint); // نقطة علوية
    canvas.drawCircle(Offset(center.dx, s * 68 / 76), dotR, dotPaint); // نقطة سفلية
  }

  @override
  bool shouldRepaint(covariant _MoaatmatPainter old) =>
      old.accent != accent || old.ring != ring || old.dot != dot;
}
