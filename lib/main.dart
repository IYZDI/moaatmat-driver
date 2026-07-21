import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // نُهيّئ Supabase فقط عند توفّر الإعدادات؛ وإلا يعمل التطبيق بالبيانات التجريبية.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // المفتاح العلني (anon/publishable) — نفس مشروع الداشبورد. المندوب يُصادَق
      // برمز الجلسة داخل دوال RPC (لا جلسة Supabase)، ورمز المؤسسة يحمل المؤسسة.
      publishableKey: Env.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: MoaatmatDriverApp()));
}

class MoaatmatDriverApp extends ConsumerWidget {
  const MoaatmatDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Moaatmat Driver',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
