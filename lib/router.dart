// material.dart يغني عن foundation.dart (كان مستوردًا قبل إضافة SwipeBack).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'state.dart';
import 'widgets.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pickup_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/map_screen.dart';
import 'screens/deliver_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

/// يلفّ الشاشة بإيماءة «اسحب للرجوع»: تُفضَّل عودةُ المكدّس إن وُجد، وإلّا
/// فالوجهةُ الأمّ المصرَّح بها — وهي نفسُها التي يذهب إليها سهمُ الشاشة.
Widget _back(BuildContext context, String parent, Widget child) => SwipeBack(
      onBack: () => context.canPop() ? context.pop() : context.go(parent),
      child: child,
    );

GoRouter buildRouter(Ref ref, Listenable refreshListenable) {
  return GoRouter(
    initialLocation: '/splash',
    // يعيد تقييم redirect عند تغيّر حالة الدخول — وإلا بقي المندوب عالقًا على
    // شاشة الدخول بعد استعادة الجلسة المحفوظة (يبدو كأنه سُجّل خروجه تلقائيًّا).
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null; // السبلاش يقرّر وجهته بنفسه بعد ٣ ثوانٍ
      final authed = ref.read(driverProvider).authed;
      final atGate = loc == '/login';
      if (!authed && !atGate) return '/login';
      if (authed && atGate) return '/home';
      return null;
    },
    routes: [
      // ======================================================================
      // السحبُ من الحافة للرجوع — يُلَفّ **هنا** لا في الشاشات.
      // ----------------------------------------------------------------------
      // شاشاتُ هذا التطبيق تتنقّل بـ`go` (تبديلٌ لا تكديس)، فلا مكدّسَ تسحبه
      // إيماءةُ Flutter. ولفُّ كلّ شاشةٍ على حدة يعني جراحةَ أقواسٍ في خمسة
      // ملفّات (جرّبتُها فكسرت أربعةً) — والمُوجِّه موضعٌ واحدٌ يراه الجميع.
      //
      // و`back` لكلّ مسارٍ هو **وجهةُ سهم تلك الشاشة نفسِها**: لا يُخمَّن.
      // ولا سحبَ في `/splash` و`/login`: ليس خلفهما شيءٌ يُرجع إليه.
      // ======================================================================
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/pickup', builder: (c, s) => _back(c, '/home', const PickupScreen())),
      GoRoute(path: '/customers', builder: (c, s) => _back(c, '/home', const CustomersScreen())),
      GoRoute(path: '/history', builder: (c, s) => _back(c, '/home', const HistoryScreen())),
      GoRoute(path: '/profile', builder: (c, s) => _back(c, '/home', const ProfileScreen())),
      GoRoute(
          path: '/chat/:id',
          builder: (c, s) => _back(c, '/customers', ChatScreen(orderId: s.pathParameters['id']!))),
      GoRoute(
          path: '/map/:id',
          builder: (c, s) => _back(c, '/customers', MapScreen(orderId: s.pathParameters['id']!))),
      GoRoute(
          path: '/deliver/:id',
          builder: (c, s) => _back(c, '/home', DeliverScreen(orderId: s.pathParameters['id']!))),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen<bool>(driverProvider.select((d) => d.authed), (prev, next) => refresh.value++);
  return buildRouter(ref, refresh);
});
