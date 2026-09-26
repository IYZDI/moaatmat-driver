// ============================================================================
// 📞 توصيلةُ نقطة البيع: جوّالُ العميل لا يضيع، والعنوانُ الغائبُ يُقال غيابُه.
// ----------------------------------------------------------------------------
// ① `Order.copyWith` كان يُسقط `phone` — الحقلَ الوحيدَ المنسيَّ فيه. والانعكاسُ
//    الفوريّ في state.dart يغيّر الحالةَ بـcopyWith قبل ردّ الخادم، فبعد «تأكيد
//    التوجّه» يصير الجوّالُ `null` حتّى التحديث التالي: يختفي زرُّ الاتصال
//    ويقول الزرُّ الآخرُ «لا رقم جوّال» — وهو في طريقه إلى الباب.
// ② طلبُ نقطة البيع قد لا يحمل عنوانًا مكتوبًا (الدبّوسُ وحدَه)، وكان السطرُ
//    أيقونةً بلا نصّ. والآن يدلّ المندوبَ على الخريطة.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moaatmat_driver/models.dart';
import 'package:moaatmat_driver/state.dart';
import 'package:moaatmat_driver/screens/customers_screen.dart';

Order _order({
  String id = 'd1',
  String address = 'حي الياسمين',
  String? phone = '+966500000001',
  double? lat,
  double? lng,
}) =>
    Order(
      id: id,
      orderId: 'o$id',
      name: 'زبون الكاشير',
      initial: 'ز',
      items: 'برجر',
      address: address,
      prefTime: '',
      status: OrderStatus.ready,
      phone: phone,
      lat: lat,
      lng: lng,
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

class _FixedDriver extends DriverNotifier {
  _FixedDriver(this._fixed);
  final DriverData _fixed;
  @override
  DriverData build() => _fixed;
}

Future<void> _show(WidgetTester tester, DriverData data) async {
  tester.view.physicalSize = const Size(900 * 2, 1400 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: [driverProvider.overrideWith(() => _FixedDriver(data))],
    child: const MaterialApp(
      home: Directionality(
          textDirection: TextDirection.rtl, child: CustomersScreen()),
    ),
  ));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  test('🚨 ① copyWith يُبقي جوّالَ العميل عند تغيّر الحالة', () {
    final o = _order();
    expect(o.copyWith(status: OrderStatus.enroute).phone, '+966500000001',
        reason: 'بعد «تأكيد التوجّه» يختفي زرُّ الاتصال حتّى التحديث التالي');
  });

  testWidgets('② عنوانٌ فارغٌ ودبّوسٌ ⇒ «الموقع محدَّد على الخريطة»',
      (tester) async {
    await _show(tester,
        _data([_order(address: '', lat: 24.7, lng: 46.6)]));
    expect(find.textContaining('الموقع محدَّد على الخريطة'), findsOneWidget);
  });

  testWidgets('③ عنوانٌ فارغٌ بلا دبّوس ⇒ «لا عنوان مسجَّل»', (tester) async {
    await _show(tester, _data([_order(address: '')]));
    expect(find.textContaining('لا عنوان مسجَّل'), findsOneWidget);
  });

  testWidgets('④ عنوانٌ مكتوب ⇒ يُعرض كما هو ولا جملةَ بديلة', (tester) async {
    await _show(tester, _data([_order(), _order(id: 'd2')]));
    expect(find.text('حي الياسمين'), findsNWidgets(2));
    expect(find.textContaining('لا عنوان'), findsNothing);
  });

  testWidgets('⑤ جوّالٌ بعد تغيّر الحالة ⇒ زرُّ الاتصال في بطاقة الانتظار باقٍ',
      (tester) async {
    final waiting = _order(id: 'd2').copyWith(status: OrderStatus.enroute);
    await _show(tester, _data([_order(), waiting]));
    // بطاقةُ «التالي» تحمل زرَّ الهاتف دائمًا، وبطاقةُ الانتظار حين يوجد رقم.
    expect(find.byIcon(Icons.phone_outlined), findsNWidgets(2),
        reason: 'سقط الجوّالُ في copyWith فأُخفي زرُّ الاتصال');
  });
}
