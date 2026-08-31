import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// وجهةُ نقرةِ الإشعار في تطبيق المندوب.
///
/// 🚨 **لم يكن التطبيق يستمع للنقرة إطلاقًا.** مسحُ `driver_app/lib` عن
/// `onMessage` و`onMessageOpenedApp` و`getInitialMessage` و`onBackgroundMessage`
/// أعاد **صفرَ نتائج**: `push_service` تقتصر على التهيئة وتسجيل الرمز.
/// والخادمُ يرسل وجهةً كاملةً منذ البداية:
///     `_push_driver_assignment` ⇒ {'type':'assignment','delivery_id': …}
///     `_push_driver_message`    ⇒ {'type':'chat','order_id':…,'delivery_id':…}
/// فكانت تُهمَل كلُّها ويُفتح التطبيقُ على الشاشة الأولى.
///
/// وهو العطلُ نفسُه الذي أُصلح في تطبيق العميل (0444) ولم يُنقَل إلى هنا.
///
/// ⚠ **والوجهةُ تُبنى من قائمةٍ بيضاء، لا من نصٍّ يأتي مع الإشعار.** حمولةُ
///   الإشعار مدخَلٌ خارجيّ: لو أُخذ منها مسارٌ جاهزٌ لصار من يستطيع إرسال
///   إشعارٍ يستطيع توجيهَ المندوب إلى أيّ شاشة. فالمقروءُ منها **نوعٌ ومعرّف**
///   لا غير، والمسارُ يُركَّب هنا.
///
/// ⚠ ويُفحص المعرّفُ شكلًا: `go` تقبل أيّ نصّ، ومعرّفٌ مشوّهٌ يفتح شاشةً
///   تبحث عن توصيلةٍ لا وجودَ لها فتبقى فارغةً بلا تفسير.
final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

@visibleForTesting
String? routeForPush(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  final delivery = (data['delivery_id'] ?? '').toString();
  if (!_uuid.hasMatch(delivery)) return null;
  switch (type) {
    case 'chat':
      return '/chat/$delivery';
    case 'assignment':
      // لا شاشةَ تفصيلٍ للتوصيلة في هذا التطبيق: الخريطةُ هي أقربُ ما يصف
      // «توصيلةٌ أُسندت إليك» — وفيها العنوانُ والمسار.
      return '/map/$delivery';
    default:
      return null; // نوعٌ لا نعرفه: تُفتح الشاشةُ الأولى كما كان
  }
}

/// يوصّل نقرةَ الإشعار بالتوجيه. `go` تُمرَّر من الأعلى فلا يعتمد هذا الملفّ
/// على المُوجِّه مباشرةً — ويبقى قابلًا للقياس.
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

    // ① التطبيقُ في الخلفيّة والمستخدمُ ينقر.
    FirebaseMessaging.onMessageOpenedApp.listen(follow);

    // ② التطبيقُ **مغلقٌ تمامًا** — وهي الحالةُ الأغلب، ومن يعالج الأولى
    //    وحدَها يظنّ العطلَ مُصلحًا وهو باقٍ.
    try {
      follow(await FirebaseMessaging.instance.getInitialMessage());
    } catch (_) {
      // غيابُ Firebase في بناءٍ بلا مفاتيح: لا نقرةَ تُتبَع، ولا عطلَ يُصعَّد.
    }
  }
}
