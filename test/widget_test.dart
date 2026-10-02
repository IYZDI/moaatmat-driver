import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/data/action_queue.dart' show QueueClock;
import 'package:moaatmat_driver/data/mock_driver_repository.dart';
import 'package:moaatmat_driver/main.dart';
import 'package:moaatmat_driver/screens/route_screen.dart';
import 'package:moaatmat_driver/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الرحلةُ الأولى كاملةً على الخادم الوهميّ: دخول ⇒ «حمّل أكياسك» ⇒ تحميلُ كيس ⇒
/// «ابدأ المسار» ⇒ بطاقةُ المحطة الحاليّة برقم كيسها و«تم التسليم».
void main() {
  testWidgets('دخول ثمّ تحميل ثمّ بدء المسار', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // شاشةُ هاتفٍ لا نافذةُ الاختبار الافتراضيّة (800×600 أفقيّة).
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // مهلُ التراجع تُقاس بساعة الاختبار المزيّفة لا بساعة الجهاز.
    QueueClock.now = () => tester.binding.clock.now();
    addTearDown(() => QueueClock.now = DateTime.now);

    final repo = MockDriverRepository(latency: const Duration(milliseconds: 10));
    await tester.pumpWidget(ProviderScope(
      overrides: [driverRepositoryProvider.overrideWithValue(repo)],
      child: const MoaatmatDriverApp(useGoogleFonts: false),
    ));

    // البداية ⇒ الدخول (لا جلسةَ محفوظة).
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('أرسل رمز التحقّق'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'DEMO1');
    await tester.enterText(find.byType(TextField).at(1), '0500000099');
    await tester.tap(find.text('أرسل رمز التحقّق'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    // الخادمُ الوهميّ بلا اسمٍ للمندوب ⇒ يُسأل مرّة.
    expect(find.text('ما اسمك؟'), findsOneWidget);
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();

    expect(find.text('حمّل أكياسك'), findsOneWidget);
    expect(find.text('حمّلت 0 من 8'), findsOneWidget);

    // لمسُ كيس سارة (#3) يحمّله — ويظهر شريطُ التراجع.
    await tester.tap(find.text('#3'));
    await tester.pump();
    expect(find.textContaining('تراجع'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('حمّلت 1 من 8'), findsOneWidget);

    final start = find.textContaining('ابدأ المسار');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    // أكياسٌ لم تُحمَّل ⇒ يُسأل قبل البدء.
    expect(find.text('ابدأ بدونها؟'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(RouteScreen)));
    final current = container.read(currentGroupProvider)?.current;
    expect(current, isNotNull);
    expect(find.text(current!.bagLabel), findsWidgets);
    expect(find.text('تم التسليم'), findsOneWidget);
    expect(find.text('المحطة 1 من 8'), findsOneWidget);

    // تفكيكُ الشجرة يوقف مؤقّتات الحالة (الاستطلاع والطابور).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  });
}
