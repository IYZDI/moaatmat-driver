import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// وجهةُ نقرةِ الإشعار في تطبيق المندوب.
///
/// الخادمُ يرسل (0601):
///     {'type':'route', 'date': …}           ⇒ إشعارٌ واحدٌ مجمَّع لمسار اليوم ⇒ /route
///     {'type':'chat', 'delivery_id': …}     ⇒ رسالةُ عميل ⇒ `/chat/<id>`
///     {'type':'assignment', 'delivery_id'}  ⇒ النسخةُ القديمة (إشعارٌ لكلّ توصيلة) ⇒ /route
///
/// ⚠ **الوجهةُ تُبنى من قائمةٍ بيضاء، لا من نصٍّ يأتي مع الإشعار.** الحمولةُ
///   مدخَلٌ خارجيّ: لو أُخذ منها مسارٌ جاهز لصار من يرسل إشعارًا يوجّه المندوبَ
///   إلى أيّ شاشة. فالمقروءُ نوعٌ ومعرّفٌ لا غير، والمسارُ يُركَّب هنا.
/// ⚠ والمعرّفُ يُفحص شكلًا: معرّفٌ مشوّهٌ يفتح محادثةً تبحث عن توصيلةٍ لا وجودَ لها.
final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

@visibleForTesting
String? routeForPush(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  switch (type) {
    case 'route':
    case 'assignment':
      // المسارُ كلُّه هو الوجهة — لا شاشةَ لتوصيلةٍ منفردة، فالمعرّفُ لا يُقرأ.
      return '/route';
    case 'chat':
      final delivery = (data['delivery_id'] ?? '').toString();
      return _uuid.hasMatch(delivery) ? '/chat/${delivery.toLowerCase()}' : null;
    default:
      return null; // نوعٌ لا نعرفه: تُفتح الشاشةُ الأولى
  }
}

/// يوصّل نقرةَ الإشعار بالتوجيه. `go` تُمرَّر من الأعلى فلا يعتمد هذا الملفّ
/// على المُوجِّه — ويبقى قابلًا للقياس.
class PushTaps {
  PushTaps._();

  static bool _wired = false;

  static Future<void> wire(void Function(String route) go) async {
    if (_wired) return;
    _wired = true;

    void follow(RemoteMessage? m) {
      if (m == null) return;
      final r = routeForPush(m.data);
      if (r != null) go(r);
    }

    // كلاهما داخل `try`: بلا Firebase (بناءٌ بلا مفاتيح) يرمي لمسُ `FirebaseMessaging`
    // نفسُه [core/no-app] — لا نقرةَ تُتبَع حينها، ولا عطلَ يُصعَّد إلى المُلتقِط.
    try {
      // ① التطبيقُ في الخلفيّة والمستخدمُ ينقر.
      FirebaseMessaging.onMessageOpenedApp.listen(follow);
      // ② التطبيقُ **مغلقٌ تمامًا** — الحالةُ الأغلب.
      follow(await FirebaseMessaging.instance.getInitialMessage());
    } catch (_) {}
  }
}
