import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../moaatmat_logo.dart';
import '../widgets/app_mark.dart';
import '../state.dart';
import '../theme.dart';

/// ============================================================================
/// شاشةُ البدء — لا تنتظر وقتًا ثابتًا: تنتقل لحظةَ تنتهي استعادةُ الجلسة،
/// وبحدٍّ أدنى 700 ملّي ثانية كي لا تومض العلامةُ وتختفي كخلل.
/// ============================================================================
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.from});

  /// وجهةٌ طُلبت أثناء الاستعادة (نقرةُ إشعار) — يُذهب إليها بعدها.
  final String? from;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minElapsed = false;
  bool _left = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 700), () {
      _minElapsed = true;
      _maybeLeave();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeLeave() {
    if (!mounted || _left || !_minElapsed) return;
    final auth = ref.read(driverProvider).auth;
    if (auth == AuthStatus.restoring) return;
    _left = true;
    final from = widget.from;
    // الوجهةُ المحفوظة تُقبل إن كانت مسارًا داخليًّا فقط (تبدأ بـ«/» لا «//»).
    final safe = from != null && from.startsWith('/') && !from.startsWith('//') && from != '/splash';
    context.go(auth == AuthStatus.signedIn ? (safe ? from : '/route') : '/login');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(driverProvider.select((s) => s.auth), (_, _) => _maybeLeave());
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.surface,
      body: Stack(
        children: [
          Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppMark(size: 96),
            const SizedBox(height: 20),
            Text(t.appName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.ink)),
            const SizedBox(height: 6),
            Text(t.tagline, style: TextStyle(fontSize: TextSizes.body, color: p.muted)),
          ],
        ),
          ),
          // توقيعُ المنصّة صغيرًا أسفلَ الشاشة: التطبيقُ للمندوب، والشعارُ لمؤتمت.
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MoaatmatLogo(size: 20),
                  const SizedBox(width: 8),
                  Text(t.ar ? 'مؤتمت' : 'Moaatmat',
                      style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: p.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
