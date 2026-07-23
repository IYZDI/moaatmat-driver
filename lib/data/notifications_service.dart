import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// إشعارات النظام المحلية — تُستخدم لرسائل المحادثة الواردة أثناء عمل التطبيق
/// (في المقدّمة أو الخلفية). الإشعار عند إغلاق التطبيق كليًّا يتطلّب FCM/APNs لاحقًا.
class NotificationsService {
  NotificationsService._();
  static final instance = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _seq = 0;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    // أندرويد 13+: إذن الإشعارات إذن تشغيلي يجب طلبه صراحةً.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// يعرض إشعار رسالة محادثة.
  Future<void> showMessage({required String title, required String body}) async {
    if (!_ready) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_messages',
        'رسائل المحادثة',
        channelDescription: 'إشعارات رسائل العملاء أثناء التوصيل',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
    );
    await _plugin.show(_seq++, title, body, details);
  }
}
