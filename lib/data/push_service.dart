import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// إشعارات فورية (FCM) للمندوب: تصل حتى والتطبيق مغلق.
/// المندوب يُصادَق برمز جلسة، فيُسجَّل رمز الجهاز عبر driver_register_device_token.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _inited = false;
  bool _registered = false;
  bool _registering = false;

  /// تهيئة Firebase — تُستدعى عند الإقلاع. أي فشل يُتجاهل (التطبيق يعمل بلا دفع).
  ///
  /// على iOS تُهيّئ AppDelegate التطبيقَ مبكرًا (ليلتقط رمز APNs الصادر لحظة
  /// الإقلاع)، فلا نُعيد التهيئة إن كانت تمّت.
  Future<void> init() async {
    if (_inited || kIsWeb || !Env.hasFirebase) return;
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
        } catch (_) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      await save(token);
      messaging.onTokenRefresh.listen((t) => save(t).catchError((_) {}));
      _registered = token != null;
    } catch (e) {
      debugPrint('PushService.registerToken: $e');
    } finally {
      _registering = false;
    }
  }
}
