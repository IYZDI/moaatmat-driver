import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// ============================================================================
/// التقاطُ الانهيار في تطبيق المندوب (0296).
/// ----------------------------------------------------------------------------
/// لم يكن فيه التقاطٌ ألبتّة، فانهيارُ المندوب في الطريق لا يبقى منه أثرٌ يُقرأ.
///
/// ⚠ وهذا التطبيقُ **مجهولٌ تمامًا**: لا جلسةَ Supabase له، بل رمزُ جلسةٍ
///   يُمرَّر لكلّ دالّة. فيُرسَل الرمزُ مع التقرير لتُعرف مؤسّستُه — وبدونه
///   يصير التقريرُ بلا صاحبٍ ولا يُعرف أيُّ مطعمٍ انهار مندوبُه.
///
/// وما يُرسَل: الرسالةُ والمكدّسُ واسمُ الشاشة. ولا بياناتِ عميلٍ ولا موقع.
/// ============================================================================
class CrashReporter {
  CrashReporter._();

  static String? currentRoute;

  /// يضبطه المستودعُ عند تسجيل الدخول — ويبقى فارغًا قبله (فالانهيارُ قبل
  /// الدخول يُبلَّغ بلا مؤسّسة، وهو خيرٌ من ألّا يُبلَّغ).
  static String? driverToken;

  static String? _lastMessage;
  static DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  static void install(void Function() runApp) {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      prior?.call(details);
      _report(details.exceptionAsString(), details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _report(error.toString(), stack);
      return true;
    };
    runZonedGuarded(runApp, (error, stack) => _report(error.toString(), stack));
  }

  static void _report(String message, StackTrace? stack) {
    final now = DateTime.now();
    if (message == _lastMessage && now.difference(_lastAt).inSeconds < 5) return;
    _lastMessage = message;
    _lastAt = now;

    if (!Env.hasSupabase) return;
    unawaited(() async {
      try {
        await Supabase.instance.client.rpc('log_app_error', params: {
          'p_app': 'driver',
          'p_message': message,
          'p_stack': stack?.toString(),
          'p_route': currentRoute,
          'p_token': driverToken,
        });
      } catch (_) {
        // فشلُ الإبلاغ لا يُبلَّغ عنه.
      }
    }());
  }
}
