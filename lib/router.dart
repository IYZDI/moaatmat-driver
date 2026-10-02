import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/crash_reporter.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/route_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/splash_screen.dart';
import 'state.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// ============================================================================
/// المُوجِّه — حارسُ الجلسة في موضعٍ واحد:
///   • أثناء الاستعادة: كلُّ وجهةٍ تمرّ بالبداية وتُحفظ لتُفتح بعدها (نقرةُ إشعار).
///   • خارج الجلسة: الدخولُ وحدَه، ومعه ماسحُ رمز المطعم.
///   • داخلها: لا رجوعَ إلى الدخول.
/// التبويباتُ الثلاثة `StatefulShellRoute`: كلٌّ يحفظ تمريرَه وحالتَه، والشاشاتُ
/// الكاملة (محادثة · خريطة · ماسح) تُدفع فوقها وتُرجَع بـ`pop`.
/// ============================================================================
String? authRedirect(AuthStatus auth, Uri uri) {
  final path = uri.path;
  if (path == '/splash') return null; // البدايةُ تقرّر وجهتَها بنفسها
  if (auth == AuthStatus.restoring) {
    return Uri(path: '/splash', queryParameters: {'from': uri.toString()}).toString();
  }
  final orgScan = path == '/scan' && uri.queryParameters['mode'] == 'org';
  if (auth == AuthStatus.signedOut) {
    return (path == '/login' || orgScan) ? null : '/login';
  }
  if (path == '/login') return '/route';
  return null;
}

GoRouter buildRouter(Ref ref, Listenable refresh) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(ref.read(driverProvider).auth, state.uri),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (c, s) => SplashScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/route', builder: (c, s) => const RouteScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (c, s) => const HistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (c, s) => ChatScreen(stopId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/map', parentNavigatorKey: rootNavigatorKey, builder: (c, s) => const MapScreen()),
      GoRoute(
        path: '/scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (c, s) => ScannerScreen(mode: s.uri.queryParameters['mode'] == 'org' ? 'org' : 'bags'),
      ),
    ],
  );
  // اسمُ الشاشة يُرسل مع تقرير الانهيار — يُعرف أين سقط المندوب.
  router.routerDelegate.addListener(() {
    CrashReporter.currentRoute = router.routerDelegate.currentConfiguration.uri.path;
  });
  return router;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  // يعيد تقييمَ الحارس حين تتغيّر الجلسة — وإلّا بقي المندوبُ على شاشة الدخول
  // بعد الاستعادة، أو داخل التطبيق بعد موت الجلسة.
  ref.listen(driverProvider.select((s) => s.auth), (_, _) => refresh.value++);
  final router = buildRouter(ref, refresh);
  ref.onDispose(router.dispose);
  return router;
});
