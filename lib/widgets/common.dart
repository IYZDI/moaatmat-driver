import 'package:flutter/material.dart';

import '../theme.dart';

/// عنوانُ قسمٍ صغير («التالي» · «الإعدادات») — مع ذيلٍ اختياريّ.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 8)});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w800, color: p.ink2)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// حالةٌ فارغة تقول ما يحدث وما بعده — لا شاشةَ بيضاء تُترك للتخمين.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: p.muted),
          ),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.ink)),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: TextSizes.body, height: 1.6, color: p.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// سطرُ تقدّم: «حمّلت 4 من 12» أو «المحطة 8 من 18 · باقي 11» وتحته شريط.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key, required this.title, this.trailing, required this.value, this.success = false});

  final String title;
  final String? trailing;
  final double value;

  /// الأخضرُ للتحميل (كلُّ كيسٍ محمَّلٍ «تمّ»)، والنيليُّ للطريق.
  final bool success;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w800, color: p.ink)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w700, color: p.muted)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 8,
            backgroundColor: p.surface2,
            color: success ? p.success : p.primary,
          ),
        ),
      ],
    );
  }
}

/// رقاقةُ معلومة: فترة · مسافة · وجبات.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: p.ink2),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: p.ink2)),
          ),
        ],
      ),
    );
  }
}

/// وسمٌ صغير ملوّن («لم يُحمَّل» · «في المطبخ»).
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: fg)),
      );
}

/// بطاقةٌ بإطارٍ خفيف — الحاويةُ الموحّدة.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // `Material` لا `Container`: صفوفُ القوائم (ListTile) ترسم تموّجَ اللمس على
    // أقرب Material، وخلفيّةُ Container ملوّنة تُخفيه (وتُطلق تحذيرًا في التطوير).
    return Material(
      color: color ?? p.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
