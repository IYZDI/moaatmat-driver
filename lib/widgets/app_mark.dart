import 'package:flutter/material.dart';

/// أيقونةُ «مندوب مؤتمت» (سهم الملاحة) — الصورةُ نفسُها التي على الشاشة الرئيسيّة
/// للهاتف، فيرى المندوبُ داخل التطبيق ما ضغطه ليفتحه. مصدرُها المتّجه في
/// `assets/icon/app_icon.svg`، والمقاساتُ كلُّها تُولَّد منه.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/app_icon.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        semanticLabel: 'مندوب مؤتمت',
      );
}
