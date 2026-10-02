import 'package:flutter/material.dart';

import '../theme.dart';

/// رقمُ الكيس كما على الملصق «#12» — أوّلُ ما تبحث عنه العينُ في صندوق السيّارة،
/// فهو أكبرُ ما في البطاقة وبخطٍّ أرقامُه متساوية العرض.
class BagBadge extends StatelessWidget {
  const BagBadge(this.label, {super.key, this.fontSize = TextSizes.bag, this.muted = false});

  final String label;
  final double fontSize;

  /// للمحطّات المغلقة: الرقمُ باقٍ للمرجع لكنّه لم يعد يطلب انتباهًا.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.35, vertical: fontSize * 0.1),
      decoration: BoxDecoration(
        color: muted ? p.surface2 : p.primarySoft,
        borderRadius: BorderRadius.circular(fontSize * 0.4),
      ),
      child: Text(
        label,
        // الرقمُ يُقرأ يسارًا ليمين حتى في الواجهة العربيّة: «#12» لا «12#».
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: muted ? p.muted : p.primaryText,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
