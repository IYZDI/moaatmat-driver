// ============================================================================
// 🔔 نقرةُ الإشعار تفتح ما يخصّها — والحمولةُ لا تختار الشاشة.
// ----------------------------------------------------------------------------
//   ① كلُّ نوعٍ يرسله الخادمُ له وجهةٌ صحيحة (0601: إشعارٌ واحدٌ للمسار)؛
//   ② والحمولةُ **لا تُملي مسارًا**: يُقرأ منها نوعٌ ومعرّفٌ لا غير.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/data/push_taps.dart';

const _id = '3f1a2b4c-5d6e-7f80-9a1b-2c3d4e5f6071';

void main() {
  group('T · وجهةُ نقرة الإشعار', () {
    test('T-1 · رسالةُ عميل تفتح محادثةَ توصيلتها', () {
      expect(routeForPush({'type': 'chat', 'delivery_id': _id}), '/chat/$_id');
      expect(routeForPush({'type': 'chat', 'delivery_id': _id.toUpperCase()}), '/chat/$_id');
    });

    test('T-2 · إشعارُ المسار المجمَّع يفتح «مساري»', () {
      expect(routeForPush({'type': 'route', 'date': '2026-10-02'}), '/route');
      expect(routeForPush({'type': 'route'}), '/route');
    });

    test('T-3 · إشعارُ الإسناد القديم (نسخٌ قبل 0601) يفتح «مساري» أيضًا', () {
      expect(routeForPush({'type': 'assignment', 'delivery_id': _id}), '/route');
      expect(routeForPush({'type': 'assignment', 'delivery_id': '../x'}), '/route',
          reason: 'المعرّفُ لا يدخل المسار فلا يُفحص');
    });

    test('T-4 · 🚨 الحمولةُ لا تُملي مسارًا', () {
      expect(routeForPush({'type': 'chat', 'delivery_id': _id, 'route': '/profile'}), '/chat/$_id');
      expect(routeForPush({'route': '/profile'}), isNull);
      expect(routeForPush({'type': '/profile', 'delivery_id': _id}), isNull);
    });

    test('T-5 · 🚨 معرّفٌ مشوّهٌ لا يفتح محادثةً تبحث عن لا شيء', () {
      for (final bad in ['', 'abc', '../../profile', '$_id/x', 'null']) {
        expect(routeForPush({'type': 'chat', 'delivery_id': bad}), isNull,
            reason: 'مُرِّر معرّفٌ غيرُ صالح فبُني منه مسار: $bad');
      }
    });

    test('T-6 · نوعٌ مجهولٌ يُترك للشاشة الأولى', () {
      expect(routeForPush({'type': 'promo', 'delivery_id': _id}), isNull);
      expect(routeForPush(const {}), isNull);
    });
  });
}
