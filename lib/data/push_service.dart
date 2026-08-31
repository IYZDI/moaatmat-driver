import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// إشعارات فورية (FCM) للمندوب: تصل حتى والتطبيق مغلق.
/// المندوب يُصادَق برمز جلسة، فيُسجَّل رمز الجهاز عبر driver_register_device_token.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _inited = false;
  bool _registered = false;

  /// أرمزُ هذا الجهاز مسجَّلٌ في الخادم الآن؟ (مفتاحُ الإشعارات يقرؤه.)
  bool get registered => _registered;

  /// مفتاحُ تفضيل المندوب في هذا الجهاز.
  ///
  /// ⚠ **ويُقرأ قبل التسجيل التلقائيّ**: بدونه يُعيد `registerToken` — وهي
  ///   تُنادى عند كلّ اتّصال — تسجيلَ الجهاز فيُلغي اختيارَ من أطفأ الإشعارات
  ///   عند أوّل فتحٍ للتطبيق. أي أنّ المفتاح يعود زينةً من بابٍ آخر.
  static const _prefKey = 'driver_push_enabled';

  static Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_prefKey) ?? true;
    } catch (_) {
      return true; // تعذّرت القراءة: الافتراضُ تشغيلٌ كما كان
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_prefKey, v);
    } catch (_) {/* لا شيء: الفعلُ في الخادم وقع، والتفضيلُ راحةٌ لا حقيقة */}
  }
  bool _registering = false;
  bool _apns = false;
  String _permission = '—';
  String _lastError = '';

  /// ملخّص حالة سلسلة الإشعارات — يظهر في «حسابي» بضغطة مطوّلة على الاسم.
  String get statusSummary {
    final env = Env.hasFirebase ? '✓' : '✗';
    final init = _inited ? '✓' : '✗';
    final apns = _apns ? '✓' : '✗';
    final reg = _registered ? '✓' : '✗';
    final err = _lastError.isEmpty ? '' : ' | $_lastError';
    return 'Env $env · Init $init · إذن $_permission · APNs $apns · رمز $reg$err';
  }

  /// تهيئة Firebase — تُستدعى عند الإقلاع. أي فشل يُتجاهل (التطبيق يعمل بلا دفع).
  ///
  /// على iOS تُهيّئ AppDelegate التطبيقَ مبكرًا (ليلتقط رمز APNs الصادر لحظة
  /// الإقلاع)، فلا نُعيد التهيئة إن كانت تمّت.
  Future<void> init() async {
    if (_inited || kIsWeb) return;
    // الخروجُ هنا بلا سجلٍّ هو ما أخفى بناءَ أندرويد بلا مفاتيح: خطوةٌ خضراء
    // وتطبيقٌ لا يُسجَّل له جهازٌ قطّ. الحارسُ في خطّ البناء يمنع تكرارَها،
    // وهذا السطر يجعل الحالةَ مقروءةً في بناءٍ محلّيّ كذلك.
    if (!Env.hasFirebase) {
      debugPrint('PushService: لا مفاتيح Firebase في هذه الحزمة — لا إشعارات فورية');
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: Env.firebaseApiKey,
            appId: Env.firebaseAppId,
            messagingSenderId: Env.firebaseSenderId,
            projectId: Env.firebaseProjectId,
          ),
        );
      }
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _inited = true;
    } catch (e) {
      _lastError = 'init: $e';
      debugPrint('PushService.init: $e');
    }
  }

  /// طلب الإذن وتسجيل رمز الجهاز — تُستدعى بعد دخول المندوب (آمنة للتكرار).
  Future<void> registerToken(String sessionToken) async {
    if (!_inited || _registered || _registering) return;
    _registering = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      _permission = settings.authorizationStatus.name;
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS: لا يصدر رمز FCM قبل وصول رمز APNs — ننتظره حتى ~15 ثانية.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apns;
        for (var i = 0; i < 15 && apns == null; i++) {
          try {
            apns = await messaging.getAPNSToken();
          } catch (_) {}
          if (apns == null) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
        _apns = apns != null;
        if (apns == null) {
          _lastError = 'لم يصل رمز APNs (صلاحية الإشعارات/البروفايل)';
        }
      }

      Future<void> save(String? deviceToken) async {
        if (deviceToken == null || deviceToken.isEmpty) return;
        await Supabase.instance.client.rpc('driver_register_device_token', params: {
          'p_token': sessionToken,
          'p_device_token': deviceToken,
          'p_platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        });
      }

      String? token;
      for (var i = 0; i < 4 && token == null; i++) {
        try {
          token = await messaging.getToken();
        } catch (e) {
          _lastError = 'getToken: $e';
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      try {
        await save(token);
        if (token != null) _lastError = '';
      } catch (e) {
        _lastError = 'save: $e';
        rethrow;
      }
      messaging.onTokenRefresh.listen((t) => save(t).catchError((_) {}));
      _registered = token != null;
    } catch (e) {
      if (_lastError.isEmpty) _lastError = 'register: $e';
      debugPrint('PushService.registerToken: $e');
    } finally {
      _registering = false;
    }
  }

  /// إيقافُ إشعارات **هذا الجهاز** — يُلغي تسجيلَ رمزه في الخادم.
  ///
  /// 🚨 كان مفتاحُ «إشعارات الطلبات الجديدة» في صفحة الحساب حالةً محلّيّةً
  /// (`bool _notif = true`) لا تُحفظ ولا تُرسَل: يُطفئه المندوبُ فتستمرّ
  /// الإشعارات، ويعود المفتاحُ مفتوحًا عند أوّل فتحٍ للتطبيق. مفتاحٌ زينة.
  ///
  /// ولا يحتاج الإصلاحُ حقلَ تفضيلٍ في القاعدة ولا نشرَ دالّةِ حافّة: مُرسِلُ
  /// الإشعارات يقرأ صفوفَ `driver_device_tokens` — فغيابُ الصفّ **هو** الإطفاء،
  /// وهو أصدقُ تمثيلٍ للمعنى: «لا تُرسل إلى هذا الجهاز».
  Future<bool> unregisterThisDevice(String sessionToken) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return false;
      await Supabase.instance.client.rpc('driver_unregister_device_token', params: {
        'p_token': sessionToken,
        'p_device_token': token,
      });
      _registered = false;
      return true;
    } catch (e) {
      _lastError = 'unregister: $e';
      return false;
    }
  }
}
