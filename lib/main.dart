import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'data/crash_reporter.dart';
import 'data/push_service.dart';
import 'data/push_taps.dart';
import 'l10n.dart';
import 'router.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase عند توفّر الإعدادات؛ وإلّا يعمل التطبيقُ على الخادم الوهميّ.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // المفتاحُ العلنيّ — المندوبُ يُصادَق برمز الجلسة داخل كلّ دالّة، لا بجلسة Supabase.
      publishableKey: Env.supabaseAnonKey,
    );
  }
  // الإشعاراتُ الفوريّة — تُهيَّأ فقط عند توفّر إعدادات Firebase.
  await PushService.instance.init();
  // التقاطُ الانهيار يلفّ `runApp` (0296).
  CrashReporter.install(() => runApp(const ProviderScope(child: MoaatmatDriverApp())));
}

/// رسائلُ الحالة (أخطاءُ الخادم حرفيًّا، والتنبيهات) تظهر من أيّ شاشة.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MoaatmatDriverApp extends ConsumerStatefulWidget {
  const MoaatmatDriverApp({super.key, this.useGoogleFonts = true});

  /// false في الاختبارات: لا شبكةَ لجلب الخطّ.
  final bool useGoogleFonts;

  @override
  ConsumerState<MoaatmatDriverApp> createState() => _MoaatmatDriverAppState();
}

class _MoaatmatDriverAppState extends ConsumerState<MoaatmatDriverApp> {
  StreamSubscription<UiEvent>? _events;
  late final ThemeData _light = buildAppTheme(Brightness.light, useGoogleFonts: widget.useGoogleFonts);
  late final ThemeData _dark = buildAppTheme(Brightness.dark, useGoogleFonts: widget.useGoogleFonts);

  @override
  void initState() {
    super.initState();
    _events = ref.read(driverProvider.notifier).events.listen(_showEvent);
    // ⛔ نقرةُ الإشعار تُوصَّل مرّةً بعد بناء المُوجِّه (الدالّةُ تحرس التكرار).
    //   وبلا Firebase لا نقرات — ولمسُ `FirebaseMessaging` حينها يرمي [core/no-app].
    if (Env.hasFirebase) {
      final router = ref.read(routerProvider);
      unawaited(PushTaps.wire(router.go));
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _showEvent(UiEvent e) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final ctx = scaffoldMessengerKey.currentContext;
    final p = ctx == null ? Palette.light : ctx.pal;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ref.read(stringsProvider).event(e.message)),
        backgroundColor: e.error ? p.danger : null,
        // خطأُ الخادم يُقرأ كاملًا — جملةٌ عربيّةٌ للمندوب لا رمز.
        duration: Duration(seconds: e.error ? 6 : 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final lang = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Moaatmat Driver',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: _light,
      darkTheme: _dark,
      themeMode: mode,
      routerConfig: router,
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
