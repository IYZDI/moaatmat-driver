// ============================================================================
// فترةُ التوصيل على شاشات المندوب (0366) — والحالةُ الفارغةُ هي المُختبَرة.
// ----------------------------------------------------------------------------
// `delivery_slot` تأتي `null` في أغلب الصفوف (طلبُ نقطة البيع لا اشتراكَ له،
// وكلُّ اشتراكٍ أُنشئ قبل 0365 بلا فترة). فالفحصُ الذي يمرّ على الحالة
// الموجودة وحدَها فحصٌ أخضرُ كاذب: العطلُ المتوقَّع هنا فجوةٌ أو شرطةٌ معلّقة
// في البطاقة الخالية، لا غيابُ الشارة الموجودة.
//
// ⚠ وقياسُ الارتفاع هو ما يُسقط `SizedBox.shrink` لو أُعيدت إلى الودجة: بطاقةُ
//   الطلب بلا فترةٍ يجب أن تساوي **حرفيًّا** بطاقةَ ما قبل 0366، لا أن تزيد
//   مسافةً معلّقة.
//
// ⚠ ونافذةُ الاختبار عريضةٌ عمدًا (٩٠٠): خطُّ بيئة الاختبار يرسم كلَّ محرفٍ
//   مربّعًا بعرض حجمه، فالنصُّ العربيّ يخرج أعرضَ من حقيقته بأضعاف ويفيض
//   صفوفٌ لا تفيض على جهاز. فقياسُ الفيض الحقيقيّ يُعزل في اختبار الشارة
//   وحدَها داخل عرضٍ ضيّقٍ مفروض.
//
// ⚠ وبين كلّ مشهدٍ وآخر تُهدَم الشجرة (`SizedBox.shrink`): إعادةُ بناء
//   `ProviderScope` بتجاوزٍ جديدٍ فوق شجرةٍ قائمة تُبقي المُخطِر الأوّل حيًّا —
//   فيُقاس المشهدُ الثاني وهو يعرض بياناتِ الأوّل، ويخضرّ الفحصُ على لا شيء.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moaatmat_driver/models.dart';
import 'package:moaatmat_driver/state.dart';
import 'package:moaatmat_driver/widgets.dart';
import 'package:moaatmat_driver/screens/home_screen.dart';
import 'package:moaatmat_driver/screens/customers_screen.dart';

/// عنوانُ فترةٍ طويل يكتبه المطعمُ بنفسه — أطولُ ما يُتوقّع عمليًّا.
const kLongSlot = 'بعد صلاة العشاء مباشرةً (٩:٣٠ - ١١:٤٥ م) — الحيّ الشرقيّ';

Order _order({String id = 'd1', String? slot, String prefTime = ''}) => Order(
      id: id,
      orderId: 'o$id',
      name: 'سارة',
      initial: 'س',
      items: 'برجر',
      address: 'حي الياسمين',
      prefTime: prefTime,
      status: OrderStatus.ready,
      deliverySlot: slot,
    );

DriverData _data(List<Order> orders) => DriverData(
      authed: true,
      name: 'مندوب',
      phone: '+966500000000',
      orders: orders,
      history: const [],
      messages: const {},
      total: orders.length,
      delivered: 0,
      remaining: orders.length,
    );

/// يثبّت حالةً بعينها بدل بذور الوضع التجريبي.
class _FixedDriver extends DriverNotifier {
  _FixedDriver(this._fixed);
  final DriverData _fixed;
  @override
  DriverData build() => _fixed;
}

Widget _host(Widget child, DriverData data) => ProviderScope(
      overrides: [driverProvider.overrideWith(() => _FixedDriver(data))],
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

/// يهدم الشجرة ثمّ يبني المشهد الجديد نظيفًا.
Future<void> _show(WidgetTester tester, Widget screen, DriverData data) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_host(screen, data));
  await tester.pump();
}

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(900 * 2, 1400 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  test('copyWith لا يُسقط الفترة عند تغيير الحالة', () {
    final o = _order(slot: 'مساءً (٥ - ٨ م)');
    expect(o.copyWith(status: OrderStatus.enroute).deliverySlot, 'مساءً (٥ - ٨ م)');
  });

  testWidgets('الشارةُ تلتفّ ولا تفيض في عرضٍ ضيّق', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topRight,
            child: SizedBox(width: 160, child: SlotChip(kLongSlot)),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SlotChip), findsOneWidget);
    // ولا تتجاوز العرضَ المفروض عليها
    expect(tester.getSize(find.byType(SlotChip)).width, lessThanOrEqualTo(160));
  });

  testWidgets('الرئيسية: فترةٌ غائبة لا تترك أثرًا ولا ارتفاعًا', (tester) async {
    _wide(tester);

    // ① بلا فترة — قياسُ ارتفاع البطاقة المرجعيّ
    await _show(tester, const HomeScreen(), _data([_order()]));
    expect(find.byType(SlotChip), findsNothing);
    expect(find.textContaining('فترة التوصيل'), findsNothing);
    // ولا عنوانَ «التوصيل المفضّل» بلا قيمةٍ بعده
    expect(find.textContaining('التوصيل المفضّل'), findsNothing);

    // ⚠ وهذا هو الحارسُ الفعليّ للفجوة المعلّقة: المسافةُ بين شارة الحالة
    //   وسطر المعرّف هي مسافةُ البطاقة الأصليّة وحدَها (٨). ولو خرجت
    //   `SizedBox` الشارةِ من الحراسة لتضاعفت — وهو عطلٌ لا يراه أيُّ
    //   `findsNothing` لأنّ ما يبقى فراغٌ لا ودجة.
    final gap = tester.getRect(find.textContaining('#')).top -
        tester.getRect(find.byType(StatusBadge)).bottom;
    expect(gap, 8.0, reason: 'فجوةٌ زائدة = مسافةٌ بقيت بعد شارةٍ لم تُبنَ');

    final bare = tester.getSize(find.byType(AppCard).first).height;

    // ② بفترة — الشارةُ تظهر والبطاقةُ تعلو
    await _show(tester, const HomeScreen(), _data([_order(slot: kLongSlot)]));
    expect(find.byType(SlotChip), findsOneWidget);
    expect(tester.getSize(find.byType(AppCard).first).height, greaterThan(bare));

    // ③ ثمّ تغيب مرّةً أخرى — يعود الارتفاع كما كان بلا فجوةٍ متبقّية
    await _show(tester, const HomeScreen(), _data([_order()]));
    expect(tester.getSize(find.byType(AppCard).first).height, bare);
  });

  testWidgets('العملاء: بطاقتا «التالي» و«الانتظار» — الحالتان جنبًا إلى جنب',
      (tester) async {
    _wide(tester);

    // كلتاهما بلا فترة: لا شارةَ ولا عنوانَ معلّق في أيٍّ منهما
    await _show(tester, const CustomersScreen(),
        _data([_order(id: 'a'), _order(id: 'b')]));
    expect(find.byType(SlotChip), findsNothing);
    expect(find.textContaining('التوصيل المفضّل'), findsNothing);
    final bareNext = tester.getSize(find.byType(AppCard).at(0)).height;
    final bareWait = tester.getSize(find.byType(AppCard).at(1)).height;

    // «التالي» وحدَها بفترة — والثانيةُ لم يتغيّر شكلُها
    await _show(tester, const CustomersScreen(),
        _data([_order(id: 'a', slot: kLongSlot), _order(id: 'b')]));
    expect(find.byType(SlotChip), findsOneWidget);
    expect(tester.getSize(find.byType(AppCard).at(0)).height, greaterThan(bareNext));
    expect(tester.getSize(find.byType(AppCard).at(1)).height, bareWait);

    // والعكس: «الانتظار» وحدَها بفترة
    await _show(tester, const CustomersScreen(),
        _data([_order(id: 'a'), _order(id: 'b', slot: 'صباحًا (٨ - ١١ ص)')]));
    expect(find.byType(SlotChip), findsOneWidget);
    expect(tester.getSize(find.byType(AppCard).at(0)).height, bareNext);
    expect(tester.getSize(find.byType(AppCard).at(1)).height, greaterThan(bareWait));
  });

  testWidgets('«التوصيل المفضّل» يظهر بقيمته فقط', (tester) async {
    _wide(tester);
    await _show(tester, const CustomersScreen(),
        _data([_order(id: 'a', prefTime: '8:30 م')]));
    expect(find.textContaining('التوصيل المفضّل 8:30 م'), findsOneWidget);
  });
}
