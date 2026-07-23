// اختبار دخان: يُقلع التطبيق على السبلاش ثم ينتقل لشاشة الدخول بعد ٣ ثوانٍ.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moaatmat_driver/main.dart';

void main() {
  testWidgets('يقلع على السبلاش ثم يعرض شاشة الدخول', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    await tester.pumpWidget(const ProviderScope(child: MoaatmatDriverApp()));
    await tester.pump();

    // السبلاش: الشعار والاسم
    expect(find.text('Moaatmat Driver'), findsWidgets);
    expect(find.text('تطبيق مندوب التوصيل'), findsOneWidget);

    // بعد ٣ ثوانٍ → شاشة الدخول
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('سجّل الدخول لبدء مناوبتك'), findsOneWidget);
  });
}
