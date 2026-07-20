import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pickup_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/map_screen.dart';
import 'screens/deliver_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authed = ref.read(driverProvider).authed;
      final loc = state.matchedLocation;
      final atGate = loc == '/login';
      if (!authed && !atGate) return '/login';
      if (authed && atGate) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/pickup', builder: (c, s) => const PickupScreen()),
      GoRoute(path: '/customers', builder: (c, s) => const CustomersScreen()),
      GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/chat/:id', builder: (c, s) => ChatScreen(orderId: s.pathParameters['id']!)),
      GoRoute(path: '/map/:id', builder: (c, s) => MapScreen(orderId: s.pathParameters['id']!)),
      GoRoute(path: '/deliver/:id', builder: (c, s) => DeliverScreen(orderId: s.pathParameters['id']!)),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));
