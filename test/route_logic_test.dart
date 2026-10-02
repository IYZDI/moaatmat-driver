// ============================================================================
// منطقُ «مساري اليوم» — الترتيبُ يطابق ورقةَ المسار المطبوعة في اللوحة.
// ----------------------------------------------------------------------------
// القيمُ المتوقّعة في «R · التطابق» أُخرجت بتشغيل `deliveryRoute.js` نفسِه
// (drv-dash) في node على المدخلات نفسها — لا بحسابٍ يدويّ. فإن اختلف التطبيقُ
// عن اللوحة سقط الاختبار، والمطبخُ لا يعبّئ بترتيبٍ والمندوبُ يسير بغيره.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/models.dart';
import 'package:moaatmat_driver/route_logic.dart';

Stop st(
  String id, {
  double? lat,
  double? lng,
  StopStatus status = StopStatus.ready,
  String? slot,
  int? sort,
  String? branch = 'b1',
  LatLon? branchPos = const LatLon(24.8121, 46.6402),
  DateTime? pickedAt,
  String? dayId,
}) =>
    Stop(
      id: id,
      status: status,
      customerName: 'عميل $id',
      pos: lat == null ? null : LatLon(lat, lng!),
      slotLabel: slot,
      slotSort: sort,
      branchId: branch,
      branchPos: branchPos,
      pickedAt: pickedAt,
      subscriptionDayId: dayId,
    );

List<String> ids(List<Stop> l) => [for (final s in l) s.id];

/// المدخلُ نفسُه المُمرَّر لـ`deliveryRoute.js`.
final fixtureA = [
  st('a', lat: 24.8185, lng: 46.6391),
  st('b', lat: 24.8402, lng: 46.6550),
  st('c', lat: 24.8231, lng: 46.6468),
  st('d', lat: 24.8015, lng: 46.6273),
  st('e'),
  st('f', lat: 24.7952, lng: 46.6464),
  st('g', lat: 0, lng: 0),
  st('h', lat: 24.7408, lng: 46.6489),
  st('i', lat: 24.7790, lng: 46.6301),
];

final fixtureB = [
  st('e'),
  st('h', lat: 24.7408, lng: 46.6489),
  st('a', lat: 24.8185, lng: 46.6391),
  st('b', lat: 24.8402, lng: 46.6550),
  st('g', lat: 0, lng: 0),
  st('c', lat: 24.8231, lng: 46.6468),
  st('d', lat: 24.8015, lng: 46.6273),
  st('f', lat: 24.7952, lng: 46.6464),
  st('i', lat: 24.7790, lng: 46.6301),
];

const branch = LatLon(24.8121, 46.6402);

void main() {
  group('R · التطابق مع deliveryRoute.js', () {
    test('R-1 · المسافة هافرساين كما في اللوحة', () {
      expect(distanceKm(branch, const LatLon(24.8185, 46.6391)), closeTo(0.7202553539203844, 1e-12));
      expect(distanceKm(const LatLon(24.7136, 46.6753), const LatLon(21.4858, 39.1925)),
          closeTo(845.1007518917858, 1e-9));
      expect(distanceKm(null, branch), isNull);
      expect(distanceKm(branch, const LatLon(0, 0)), isNull);
    });

    test('R-2 · hasXY: 0,0 وNaN ليسا موقعًا', () {
      expect(hasXY(branch), isTrue);
      expect(hasXY(const LatLon(0, 0)), isFalse);
      expect(hasXY(const LatLon(double.nan, 46)), isFalse);
      expect(hasXY(const LatLon(24, double.infinity)), isFalse);
      expect(hasXY(null), isFalse);
      expect(hasXY(const LatLon(0, 46)), isTrue, reason: 'خطُّ عرضٍ صفريّ وحدَه موقعٌ صالح');
    });

    test('R-3 · أقربُ جارٍ من الفرع، وما بلا موقعٍ (فارغًا أو 0,0) في الآخر بترتيب المدخل', () {
      expect(ids(orderStops(branch, fixtureA)), ['a', 'c', 'b', 'f', 'd', 'i', 'h', 'e', 'g']);
      expect(ids(orderStops(branch, fixtureB)), ['a', 'c', 'b', 'f', 'd', 'i', 'h', 'e', 'g']);
      expect(ids(orderStops(const LatLon(24.85, 46.66), fixtureB)), ['b', 'c', 'a', 'd', 'f', 'i', 'h', 'e', 'g']);
    });

    test('R-4 · بلا نقطة بدء (أو 0,0): يبدأ من أوّل محطّةٍ لها موقع', () {
      expect(ids(orderStops(null, fixtureB)), ['h', 'i', 'f', 'd', 'a', 'c', 'b', 'e', 'g']);
      expect(ids(orderStops(const LatLon(0, 0), fixtureB)), ['h', 'i', 'f', 'd', 'a', 'c', 'b', 'e', 'g']);
    });

    test('R-5 · التعادل: الأسبقُ في المدخل يبقى أوّلًا (< صارمة)', () {
      final n = st('n', lat: 24.01, lng: 46.0), s = st('s', lat: 23.99, lng: 46.0), far = st('far', lat: 24.5, lng: 46.0);
      expect(distanceKm(const LatLon(24, 46), n.pos), distanceKm(const LatLon(24, 46), s.pos));
      expect(ids(orderStops(const LatLon(24, 46), [n, s, far])), ['n', 's', 'far']);
      expect(ids(orderStops(const LatLon(24, 46), [s, n, far])), ['s', 'n', 'far']);
    });

    test('R-6 · لا موقعَ لأحد: المدخلُ كما هو', () {
      expect(ids(orderStops(branch, [st('x'), st('y', lat: 0, lng: 0)])), ['x', 'y']);
      expect(orderStops(branch, const []), isEmpty);
    });

    test('R-7 · رابطُ خرائط جوجل يساوي رابطَ اللوحة حرفًا', () {
      final first3 = orderStops(branch, fixtureA).take(3).toList();
      expect(mapsDirUrl(branch, first3).toString(),
          'https://www.google.com/maps/dir/?api=1&destination=24.8402%2C46.655&travelmode=driving'
          '&origin=24.8121%2C46.6402&waypoints=24.8185%2C46.6391%7C24.8231%2C46.6468');
      expect(mapsDirUrl(branch, [st('x')]), isNull);
    });

    test('R-8 · الفرعُ الغالب: الأكثرُ تكرارًا، والأسبقُ عند التعادل', () {
      expect(modeOf(['x', 'y', 'y', null, null, null]), 'y');
      expect(modeOf(['x', 'y', 'y', 'x']), 'x');
      expect(modeOf(<String?>[null]), isNull);
    });
  });

  group('G · الفترات', () {
    test('G-1 · الترتيب: slot_sort ثمّ الاسم، والفارغُ آخرًا، وما بلا فترةٍ أخيرًا', () {
      final groups = buildGroups([
        st('1', slot: null),
        st('2', slot: 'مساءً', sort: 2),
        st('3', slot: 'ظهرًا', sort: null),
        st('4', slot: 'صباحًا', sort: 1),
        st('5', slot: 'ب', sort: 2),
      ]);
      expect([for (final g in groups) g.key], ['صباحًا', 'ب', 'مساءً', 'ظهرًا', '']);
      expect(groups.last.slotLabel, isNull);
    });

    test('G-2 · نقطةُ البدء = موقعُ الفرع الغالب؛ وفرعٌ بلا موقعٍ ⇒ null', () {
      const other = LatLon(24.70, 46.70);
      final g = buildGroups([
        st('a', lat: 24.71, lng: 46.70, branch: 'b2', branchPos: other),
        st('b', lat: 24.81, lng: 46.64),
        st('c', lat: 24.80, lng: 46.64),
      ]).single;
      expect(g.start, branch);
      expect(ids(g.all), ['b', 'c', 'a']);

      final noPos = buildGroups([
        st('a', lat: 24.71, lng: 46.70, branchPos: null),
        st('b', lat: 24.81, lng: 46.64, branchPos: null),
      ]).single;
      expect(noPos.start, isNull);
      expect(ids(noPos.all), ['a', 'b'], reason: 'بلا بدءٍ يبدأ من أوّل محطّةٍ لها موقع');
    });

    test('G-3 · الترتيبُ يشمل المغلق — رقمُ المحطّة لا يتبدّل بعد تسليم', () {
      final before = buildGroups(fixtureA).single;
      final after = buildGroups([
        for (final s in fixtureA) s.id == 'a' ? s.copyWith(status: StopStatus.delivered) : s,
      ]).single;
      expect(ids(after.all), ids(before.all));
    });
  });

  group('P · المراحل والترتيب الفعليّ', () {
    final sheet = [
      st('a', lat: 24.8185, lng: 46.6391, slot: 'ص', sort: 1),
      st('b', lat: 24.8231, lng: 46.6468, slot: 'ص', sort: 1),
      st('c', lat: 24.8402, lng: 46.6550, slot: 'ص', sort: 1),
      st('d', lat: 24.8015, lng: 46.6273, slot: 'ص', sort: 1),
    ];
    RouteGroupView view(List<Stop> stops, [RouteLocal local = const RouteLocal()]) =>
        buildRouteGroupViews(stops, local).single;

    test('P-1 · لم يبدأ ولا شيء في الطريق ⇒ تحميل', () {
      final v = view(sheet);
      expect(v.phase, RoutePhase.loading);
      expect(ids(v.all), ['a', 'b', 'c', 'd']);
      expect(v.current?.id, 'a');
      expect(v.total, 4);
    });

    test('P-2 · بدأ محلّيًّا، أو محطّةٌ في الطريق ⇒ على الطريق', () {
      expect(view(sheet, const RouteLocal(started: {'ص'})).phase, RoutePhase.onRoute);
      final enroute = [for (final s in sheet) s.id == 'c' ? s.copyWith(status: StopStatus.enroute) : s];
      final v = view(enroute);
      expect(v.phase, RoutePhase.onRoute);
      expect(v.current?.id, 'c', reason: 'في الطريق تغلب الترتيب: عميلُها يرى التتبّع الآن');
    });

    test('P-3 · كلُّها مغلقة ⇒ انتهى', () {
      final closed = [
        for (final s in sheet) s.copyWith(status: s.id == 'b' ? StopStatus.failed : StopStatus.delivered),
      ];
      final v = view(closed, const RouteLocal(started: {'ص'}));
      expect(v.phase, RoutePhase.done);
      expect(v.current, isNull);
      expect(v.closedCount, 4);
      expect(ids(v.failed), ['b']);
    });

    test('P-4 · المؤجَّلُ إلى الآخر بترتيب تأجيله، و«اذهب إليها الآن» أوّلًا', () {
      expect(ids(view(sheet, const RouteLocal(deferred: ['b', 'a'])).open), ['c', 'd', 'b', 'a']);
      expect(ids(view(sheet, const RouteLocal(pinned: 'd')).open), ['d', 'a', 'b', 'c']);
      expect(ids(view(sheet, const RouteLocal(pinned: 'b', deferred: ['a'])).open), ['b', 'c', 'd', 'a']);
    });

    test('P-5 · الحاليّة: أوّلُ «في الطريق» غيرِ مؤجَّل، وإلّا أوّلُ مفتوح', () {
      final s = [for (final x in sheet) x.id == 'a' || x.id == 'c' ? x.copyWith(status: StopStatus.enroute) : x];
      // «a» في الطريق لكنّه مؤجَّل ⇒ «c».
      final v = view(s, const RouteLocal(deferred: ['a']));
      expect(v.current?.id, 'c');
      expect(ids(v.open), ['c', 'b', 'd', 'a']);
      // المثبَّتةُ ليست في الطريق وغيرُها في الطريق ⇒ الطريقُ يغلب.
      expect(view(s, const RouteLocal(pinned: 'd')).current?.id, 'a');
      // المؤجَّلُ وحدَه مفتوح ⇒ هو الحاليّ.
      final onlyDeferred = [for (final x in sheet) x.id == 'b' ? x : x.copyWith(status: StopStatus.delivered)];
      expect(view(onlyDeferred, const RouteLocal(deferred: ['b'])).current?.id, 'b');
    });

    test('P-6 · عدُّ المحمَّل يشمل المغلق والمحمَّل', () {
      final s = [
        sheet[0].copyWith(status: StopStatus.delivered),
        sheet[1].copyWith(pickedAt: DateTime(2026)),
        sheet[2].copyWith(status: StopStatus.preparing),
        sheet[3],
      ];
      final v = view(s);
      expect(v.loadedCount, 2);
      expect(ids(v.notLoaded), ['c', 'd']);
      expect(s[2].inKitchen, isTrue);
    });
  });

  group('A · أثرُ الأفعال المعلّقة (بقواعد driver_set_status)', () {
    final base = [st('a'), st('b', status: StopStatus.preparing), st('c', status: StopStatus.delivered)];
    List<Stop> apply(List<StopAction> a) => applyActions(base, a, now: DateTime(2026, 10, 2));
    StopAction act(String id, String action, [String? reason]) => (deliveryId: id, action: action, reason: reason);

    test('A-1 · حُمّل ⇒ محمَّل، والمُعلَّق معلَّم', () {
      final r = apply([act('b', 'picked')]);
      expect(r[1].isLoaded, isTrue);
      expect(r[1].status, StopStatus.picked);
      expect(r[1].pending, 'picked');
      expect(r[0].pending, isNull);
    });

    test('A-2 · في الطريق ثمّ أجِّل ⇒ يعود محمَّلًا لا جاهزًا', () {
      final r = apply([act('a', 'enroute'), act('a', 'defer')]);
      expect(r[0].status, StopStatus.picked);
      expect(r[0].isLoaded, isTrue);
    });

    test('A-3 · في الطريق لا تُحيي مغلَقًا، والتعذّرُ لا يكتب فوق مسلَّمة', () {
      final r = apply([act('c', 'enroute'), act('c', 'failed', 'x')]);
      expect(r[2].status, StopStatus.delivered);
    });

    test('A-4 · سُلّم / عند الباب / تعذّر', () {
      final r = apply([act('a', 'delivered_door'), act('b', 'failed', 'العميل غير متواجد')]);
      expect(r[0].status, StopStatus.delivered);
      expect(r[0].atDoor, isTrue);
      expect(r[1].status, StopStatus.failed);
      expect(r[1].failureReason, 'العميل غير متواجد');
      expect(apply([act('a', 'delivered')])[0].handoff, 'hand');
    });
  });

  group('S · المسح', () {
    const id = '3f1a2b4c-5d6e-7f80-9a1b-2c3d4e5f6071';
    test('S-1 · ملصقُ الكيس', () {
      expect(parseBagQr('MQD:$id'), id);
      expect(parseBagQr('  mqd:${id.toUpperCase()} '), id);
      expect(parseBagQr(id), isNull);
      expect(parseBagQr('MQD:abc'), isNull);
      expect(parseBagQr('https://x/driver?code=AB12'), isNull);
    });

    test('S-2 · رمزُ المطعم: رابطٌ أو رمزٌ عارٍ', () {
      expect(parseOrgCodeQr('https://moaatmat.com/driver?code=sah12'), 'SAH12');
      expect(parseOrgCodeQr('http://demo.moaatmat.com/driver?code=ABCD&x=1'), 'ABCD');
      expect(parseOrgCodeQr('ab12cd'), 'AB12CD');
      expect(parseOrgCodeQr('https://moaatmat.com/driver'), isNull);
      expect(parseOrgCodeQr('abc'), isNull);
      expect(parseOrgCodeQr('MQD:$id'), isNull);
      expect(parseOrgCodeQr('ABCDEFGHIJKLM'), isNull, reason: 'أطولُ من ١٢');
    });
  });

  group('N · العددُ بالعربيّة', () {
    test('N-1 · محطة', () {
      expect(arStops(1), 'محطة واحدة');
      expect(arStops(2), 'محطتان');
      expect(arStops(3), '3 محطات');
      expect(arStops(10), '10 محطات');
      expect(arStops(11), '11 محطة');
      expect(arStops(18), '18 محطة');
      expect(arStops(0), '0 محطة');
      expect(arStops(103), '103 محطات');
    });

    test('N-2 · توصيلة · وجبة · مرّة', () {
      expect(arDeliveries(1), 'توصيلة واحدة');
      expect(arDeliveries(2), 'توصيلتان');
      expect(arDeliveries(7), '7 توصيلات');
      expect(arMeals(3), '3 وجبات');
      expect(arMeals(2), 'وجبتان');
      expect(arMeals(12), '12 وجبة');
      expect(arTimes(2, accusative: true), 'مرّتين');
      expect(arTimes(1), 'مرّة واحدة');
      expect(arTimes(4), '4 مرّات');
    });

    test('N-3 · الإنجليزيّة', () {
      expect(enCount(1, ArNoun.stop), '1 stop');
      expect(enCount(12, ArNoun.stop), '12 stops');
      expect(enCount(2, ArNoun.time), 'twice');
      expect(enCount(3, ArNoun.delivery), '3 deliveries');
    });
  });

  group('U · روابط الاتّصال', () {
    test('U-1 · واتساب بأرقامٍ دوليّة، والملاحةُ بالموقع ثمّ بالعنوان', () {
      expect(whatsappUri('+966 50 000 0011').toString(), 'https://wa.me/966500000011');
      expect(whatsappUri('0500000011').toString(), 'https://wa.me/966500000011');
      expect(whatsappUri(null), isNull);
      expect(telUri('+966500000011').toString(), 'tel:+966500000011');
      expect(navigationUri(st('a', lat: 24.8, lng: 46.6)).toString(), contains('destination=24.8%2C46.6'));
      expect(navigationUri(const Stop(id: 'x', status: StopStatus.ready, customerName: '', address: 'الياسمين'))
          .toString(), contains('/maps/search/'));
      expect(navigationUri(const Stop(id: 'x', status: StopStatus.ready, customerName: '')), isNull);
    });
  });
}
