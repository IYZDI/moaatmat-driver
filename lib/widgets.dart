import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'l10n.dart';
import 'theme.dart';

/// سهم الرجوع حسب اتجاه الواجهة (يمين في العربية، يسار في الإنجليزية).
IconData backChevron(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? Icons.chevron_right : Icons.chevron_left;

/// مساحة علوية آمنة بدل شريط الحالة الوهمي القديم.
///
/// كان هذا الكلاس سابقًا يرسم شريطًا وهميًّا (9:41 + بطارية/شبكة)، وهو ما كان
/// يظهر مكرَّرًا فوق شريط النظام الحقيقي على iOS ويُفسد المقاسات. الآن لم يعُد
/// يرسم شيئًا مرئيًّا: يحجز فقط ارتفاع شريط النظام الحقيقي (يشمل الـ Dynamic
/// Island) عبر `MediaQuery.padding.top`، فتنزاح المحتويات لأسفله بشكل صحيح،
/// ويضبط لون أيقونات شريط النظام حسب لون خلفية الشاشة.
class StatusBar extends StatelessWidget {
  /// true عندما تكون الخلفية داكنة/تركوازية → أيقونات النظام بيضاء.
  final bool dark;
  const StatusBar({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light, // iOS
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark, // Android
      ),
      // العرض الكامل ضروري: بعض الرؤوس (كشاشة الحساب) لا تحوي عنصرًا آخر يمدّها،
      // فلولا ذلك ينكمش الرأس التركوازي إلى عرض المحتوى ويظهر في المنتصف.
      // داخل SafeArea تكون padding.top = 0 فلا تُضاف مسافة مزدوجة.
      child: SizedBox(width: double.infinity, height: MediaQuery.of(context).padding.top),
    );
  }
}

/// مؤشّر الخطوات الثلاث: استلام ← توجّه ← تسليم. [current] = 1|2|3
class StepperBar extends ConsumerWidget {
  final int current;
  const StepperBar({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final labels = [t.stepPickup, t.stepEnroute, t.stepDeliver];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) _step(i + 1, labels[i]),
        ],
      ),
    );
  }

  Widget _step(int n, String label) {
    final done = n < current;
    final active = n == current;
    final opacity = active ? 1.0 : (done ? 0.6 : 0.55);
    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Colors.white : Colors.white.withValues(alpha: done ? 0.25 : 0.22),
              ),
              child: done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('$n', style: TextStyle(color: active ? AppColors.teal : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final String label;
  final IconData icon;
  const _NavItem(this.route, this.label, this.icon);
}

/// شريط التنقّل السفلي (يظهر في الرئيسية/السجل/حسابي).
class BottomNav extends ConsumerWidget {
  final String current;
  const BottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final items = [
      _NavItem('/home', t.navHome, Icons.home_outlined),
      _NavItem('/pickup', t.navPickup, Icons.inventory_2_outlined),
      _NavItem('/customers', t.navCustomers, Icons.people_outline),
      _NavItem('/history', t.navHistory, Icons.access_time),
      _NavItem('/profile', t.navProfile, Icons.person_outline),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final it in items)
            _item(context, it, active: it.route == current),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, _NavItem it, {required bool active}) {
    final color = active ? AppColors.teal : AppColors.muted3;
    return InkWell(
      onTap: active ? null : () => context.go(it.route),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(it.icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(it.label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

/// شارة حالة صغيرة.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const StatusBadge({super.key, required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// بطاقة بيضاء بحدّ رفيع.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color = Colors.white,
    this.borderColor,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// الرأس التركوازي بزوايا سفلية دائرية.
class TealHeader extends StatelessWidget {
  final Widget child;
  final double bottomRadius;
  const TealHeader({super.key, required this.child, this.bottomRadius = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      ),
      child: child,
    );
  }
}

/// زر أساسي تركوازي ممتلئ.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double fontSize;
  final EdgeInsets padding;
  final double radius;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.fontSize = 16,
    this.padding = const EdgeInsets.all(15),
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? const Color(0xFFC9C7C2) : AppColors.teal,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
              Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: fontSize)),
            ],
          ),
        ),
      ),
    );
  }
}

/// أيقونة مربّعة صغيرة (اتصال/موقع/محادثة).
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool teal;
  final double size;
  const SquareIconButton({super.key, required this.icon, required this.onTap, this.teal = false, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: teal ? AppColors.tealTint : AppColors.border2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 19, color: teal ? AppColors.teal : AppColors.muted2),
        ),
      ),
    );
  }
}
