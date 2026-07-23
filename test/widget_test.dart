// اختبار دخان بسيط: يتأكد أن التطبيق يُقلع ويعرض شاشة تسجيل الدخول.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moaatmat_driver/main.dart';

void main() {
  testWidgets('يقلع التطبيق ويعرض شاشة الدخول', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    await tester.pumpWidget(const ProviderScope(child: MoaatmatDriverApp()));
    await tester.pump();

    expect(find.text('Moaatmat Driver'), findsWidgets);
    // عنوان شاشة الدخول (العربية هي اللغة الافتراضية)
    expect(find.text('سجّل الدخول لبدء مناوبتك'), findsOneWidget);
  });
}
