// ============================================================================
// 🔔 نقرةُ الإشعار تفتح ما يخصّها — والحمولةُ لا تختار الشاشة.
// ----------------------------------------------------------------------------
// لم يكن التطبيقُ يستمع للنقرة إطلاقًا: مسحُ `lib` عن `onMessageOpenedApp`
// و`getInitialMessage` أعاد صفرًا، بينما يرسل الخادمُ وجهةً كاملةً منذ البداية.
// فكان المندوبُ ينقر «رسالةٌ من العميل» فيُفتح التطبيقُ على الشاشة الأولى.
//
// وهذا الملفُّ يحرس حدَّين:
//   ① كلُّ نوعٍ يعرفه الخادمُ له وجهةٌ صحيحة؛
//   ② والحمولةُ **لا تُملي مسارًا**: يُقرأ منها نوعٌ ومعرّفٌ لا غير. ولو
//      أُخذ منها مسارٌ جاهزٌ لصار من يستطيع إرسال إشعارٍ يوجّه المندوبَ
//      إلى أيّ شاشة.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/data/push_taps.dart';

const _id = '3f1a2b4c-5d6e-7f80-9a1b-2c3d4e5f6071';

void main() {
  group('T · وجهةُ نقرة الإشعار', () {
    test('T-1 · رسالةُ عميل تفتح محادثةَ توصيلتها', () {
      expect(routeForPush({'type': 'chat', 'delivery_id': _id}), '/chat/$_id');
    });

    test('T-2 · إسنادُ توصيلةٍ يفتح خريطتَها', () {
      expect(routeForPush({'type': 'assignment', 'delivery_id': _id}), '/map/$_id');
    });

    test('T-3 · 🚨 الحمولةُ لا تُملي مسارًا', () {
      // مسارٌ جاهزٌ في الحمولة يُهمَل تمامًا — المقروءُ نوعٌ ومعرّف.
      expect(routeForPush({'type': 'chat', 'delivery_id': _id, 'route': '/profile'}),
          '/chat/$_id');
      expect(routeForPush({'route': '/profile'}), isNull);
      expect(routeForPush({'type': '/profile', 'delivery_id': _id}), isNull);
    });

    test('T-4 · 🚨 معرّفٌ مشوّهٌ لا يفتح شاشةً تبحث عن لا شيء', () {
      for (final bad in ['', 'abc', '../../profile', '$_id/x', 'null']) {
        expect(routeForPush({'type': 'chat', 'delivery_id': bad}), isNull,
            reason: 'مُرِّر معرّفٌ غيرُ صالح فبُني منه مسار: $bad');
      }
    });

    test('T-5 · نوعٌ مجهولٌ يُترك للشاشة الأولى', () {
      expect(routeForPush({'type': 'promo', 'delivery_id': _id}), isNull);
      expect(routeForPush(const {}), isNull);
    });
  });
}
