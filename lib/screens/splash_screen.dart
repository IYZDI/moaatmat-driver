import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n.dart';
import '../state.dart';
import '../widgets.dart';

/// شاشة افتتاحية (٥ ثوانٍ): الشعار يظهر بحركة ارتدادية ثم الاسم، وخلالها
/// تكتمل استعادة الجلسة المحفوظة — فتهبط مباشرة على الرئيسية أو الدخول.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  late final Animation<double> _logoScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Curves.easeOutBack)));
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.4, curve: Curves.easeOut));
  late final Animation<double> _nameFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.85, curve: Curves.easeOut));
  late final Animation<Offset> _nameSlide =
      Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic)));

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), _go);
  }

  void _go() {
    if (!mounted) return;
    final authed = ref.read(driverProvider).authed;
    context.go(authed ? '/home' : '/login');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    const teal = Color(0xFF0F7268);
    return Scaffold(
      backgroundColor: teal,
      body: Stack(
        children: [
          const StatusBar(dark: true),
          // دوائر زخرفية ناعمة
          Positioned(
            top: -90,
            right: -70,
            child: _circle(240, Colors.white.withValues(alpha: 0.06)),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _circle(300, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: 140,
            right: -40,
            child: _circle(120, Colors.white.withValues(alpha: 0.04)),
          ),
          // الشعار والاسم
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset('assets/app_icon.png', width: 118, height: 118, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SlideTransition(
                  position: _nameSlide,
                  child: FadeTransition(
                    opacity: _nameFade,
                    child: Column(
                      children: [
                        const Text(
                          'Moaatmat Driver',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          t.ar ? 'تطبيق مندوب التوصيل' : 'Delivery driver app',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // مؤشّر تحميل رقيق أسفل الشاشة
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            child: FadeTransition(
              opacity: _nameFade,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
