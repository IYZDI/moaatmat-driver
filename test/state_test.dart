// ============================================================================
// حالةُ «مساري اليوم» من طرفها إلى طرفها — على الخادم الوهميّ الذي يطبّق قواعدَ
// `driver_set_status` نفسَها. المهلُ مقصّرة (٠٫١٥ و٠٫٣ ث) والزمنُ حقيقيّ.
// ============================================================================
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/data/action_queue.dart';
import 'package:moaatmat_driver/data/mock_driver_repository.dart';
import 'package:moaatmat_driver/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const timing = QueueTiming(
  loadGrace: Duration(milliseconds: 150),
  closeGrace: Duration(milliseconds: 300),
  pollEvery: Duration(hours: 1),
  chatPollEvery: Duration(hours: 1),
);

Future<void> until(bool Function() cond, {String? what, Duration timeout = const Duration(seconds: 6)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('انتهت المهلة: ${what ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class Rig {
  Rig({bool photoRequired = true, bool doorAllowed = true})
      : repo = MockDriverRepository(latency: Duration.zero, photoRequired: photoRequired, doorAllowed: doorAllowed) {
    c = ProviderContainer(overrides: [
      driverRepositoryProvider.overrideWithValue(repo),
      queueStoreProvider.overrideWithValue(MemoryQueueStore()),
      queueTimingProvider.overrideWithValue(timing),
    ]);
    sub = n.events.listen(events.add);
  }

  final MockDriverRepository repo;
  late final ProviderContainer c;
  final events = <UiEvent>[];
  late final StreamSubscription<UiEvent> sub;

  DriverNotifier get n => c.read(driverProvider.notifier);
  DriverState get s => c.read(driverProvider);
  List<RouteGroupView> get groups => c.read(routeGroupsProvider);
  RouteGroupView group(String key) => groups.firstWhere((g) => g.key == key);
  RouteGroupView get morning => group(MockDriverRepository.morning);
  Stop stop(String id) => s.stopById(id)!;

  Future<void> signIn() async {
    await until(() => s.auth == AuthStatus.signedOut, what: 'استعادة الجلسة');
    await n.sendOtp('DEMO', '0500000099');
    await n.verifyOtp('DEMO', '0500000099', '1234');
    await until(() => s.stops.isNotEmpty, what: 'تحميل المسار');
  }

  /// يحمّل ويبدأ الصباح، ويعيد ترتيبَ محطّاته المفتوحة.
  Future<List<String>> loadAndStart({int load = 3}) async {
    final order = [for (final x in morning.open) x.id];
    for (final id in order.take(load)) {
      await n.markLoaded(id);
    }
    await until(() => s.pending.isEmpty, what: 'التزامُ التحميل');
    await n.startRoute(MockDriverRepository.morning);
    return order;
  }

  void dispose() {
    sub.cancel();
    c.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QueueClock.now = DateTime.now;
  });

  test('S-1 · الدخول والتحميل: ١٣ محطّة في ثلاث فترات، والصباحُ في «حمّل أكياسك»', () async {
    final r = Rig();
    addTearDown(r.dispose);
    expect(r.s.auth, AuthStatus.restoring);
    await until(() => r.s.auth == AuthStatus.signedOut);
    expect(r.s.demo, isTrue);
    expect(await r.n.sendOtp('DEMO', '0500000099'), contains('تجريبي'));
    await expectLater(r.n.verifyOtp('DEMO', '0500000099', '12'), throwsA(isA<Exception>()));
    expect(r.s.auth, AuthStatus.signedOut);
    await r.n.verifyOtp('DEMO', '0500000099', '1234');
    expect(r.s.auth, AuthStatus.signedIn);
    expect(r.s.stops, hasLength(13));
    expect(r.s.profile?.photoRequired, isTrue);
    expect(r.s.profile?.name, isEmpty, reason: 'بلا اسم ⇒ الواجهةُ تسأله');
    expect(await r.n.setName('أحمد'), isTrue);
    expect(r.s.profile?.name, 'أحمد');

    expect([for (final g in r.groups) g.key], [MockDriverRepository.morning, MockDriverRepository.evening, '']);
    expect(r.morning.total, 8);
    expect(r.morning.phase, RoutePhase.loading);
    expect(r.morning.all.last.bagNo, 24, reason: 'بلا إحداثيّاتٍ ⇒ آخرَ الورقة');
    expect(r.c.read(currentGroupProvider)?.key, MockDriverRepository.morning);
    expect(r.s.myPos, MockDriverRepository.branchPos, reason: 'العرض: «أنا» عند الفرع قبل أوّل تسليم');
  });

  test('S-2 · حُمّل: أثرٌ فوريّ، تراجعٌ في المهلة، ثمّ يصل الخادم', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final first = r.morning.open.first;
    expect(first.isLoaded, isFalse);

    await r.n.markLoaded(first.id);
    expect(r.stop(first.id).isLoaded, isTrue);
    expect(r.stop(first.id).pending, 'picked');
    expect(r.morning.loadedCount, 1);
    final a = r.s.latestUndoable!;
    expect(a.action, 'picked');

    expect(r.n.undo(a.key), isTrue);
    expect(r.stop(first.id).isLoaded, isFalse);
    expect(r.s.pending, isEmpty);

    await r.n.markLoaded(first.id);
    await until(() => r.repo.pickedOf(first.id), what: 'وصولُ «حُمّل»');
    await until(() => r.s.pending.isEmpty);
    expect(r.stop(first.id).isLoaded, isTrue, reason: 'لا رمشةَ بين الالتزام والقراءة');
  });

  test('S-3 · المسح: حُمّل · محمّلٌ مسبقًا · ليس في مسارك · ليس ملصقًا', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final st = r.morning.open[1];
    expect(await r.n.markLoadedByScan('MQD:${st.subscriptionDayId!.toUpperCase()}'), ScanResult.loaded);
    expect(r.n.lastScannedStop?.id, st.id);
    expect(await r.n.markLoadedByScan('MQD:${st.subscriptionDayId}'), ScanResult.alreadyLoaded);
    expect(await r.n.markLoadedByScan('MQD:${MockDriverRepository.uuid(987654)}'), ScanResult.unknown);
    expect(r.n.lastScannedStop, isNull);
    expect(await r.n.markLoadedByScan('hello'), ScanResult.invalid);
  });

  test('S-4 · ابدأ المسار ⇒ الحاليّةُ في الطريق، والتسليمُ ينقل إلى التالية بعد الالتزام', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart();
    expect(r.morning.phase, RoutePhase.onRoute);
    expect(r.morning.current?.id, order[0]);
    expect(r.stop(order[0]).status, StopStatus.enroute);
    await until(() => r.repo.statusOf(order[0]) == 'out_for_delivery', what: 'في الطريق عند الخادم');

    await r.n.deliver(order[0], photo: [1, 2, 3]);
    // فورًا: أُغلقت محليًّا والتاليةُ حاليّةٌ في الطريق.
    expect(r.stop(order[0]).status, StopStatus.delivered);
    expect(r.morning.current?.id, order[1]);
    expect(r.stop(order[1]).status, StopStatus.enroute);
    expect(r.s.pending.map((p) => p.action), ['delivered'], reason: 'التابعُ الآليّ لا يظهر في شريط التراجع');
    expect(r.repo.statusOf(order[0]), 'out_for_delivery', reason: 'لم تنتهِ المهلة بعد');

    await until(() => r.repo.statusOf(order[0]) == 'delivered' && r.repo.statusOf(order[1]) == 'out_for_delivery',
        what: 'التسليمُ ثمّ التالية');
    expect(r.repo.handoffOf(order[0]), 'hand');
    expect(r.repo.photoBytes[order[0]], 3);
    await until(() => r.s.pending.isEmpty);
    expect(r.morning.current?.id, order[1]);
    expect(r.morning.closedCount, 1);
    expect(r.s.myPos, r.stop(order[0]).pos, reason: 'العرض: «أنا» عند آخر تسليم');
  });

  test('S-5 · التراجعُ يعيد المحطّة ويُلغي توجيهَ التالية، ولا يصل الخادمَ شيء', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart();
    await until(() => r.repo.statusOf(order[0]) == 'out_for_delivery');

    await r.n.deliver(order[0], photo: [1]);
    expect(r.morning.current?.id, order[1]);
    final a = r.s.latestUndoable!;
    expect(a.action, 'delivered');
    expect(r.n.undo(a.key), isTrue);

    expect(r.morning.current?.id, order[0]);
    expect(r.stop(order[0]).status, StopStatus.enroute);
    expect(r.stop(order[1]).status, isNot(StopStatus.enroute));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(r.repo.statusOf(order[0]), 'out_for_delivery');
    expect(r.repo.statusOf(order[1]), 'ready');
    expect(r.n.undo(a.key), isFalse);
  });

  test('S-6 · التعذّرُ يحتاج سببًا، والبابُ يحتاج صورة', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart();

    await r.n.fail(order[0], '   ');
    await Future<void>.delayed(Duration.zero);
    expect(r.events.last.error, isTrue);
    expect(r.events.last.message, 'اختر سبب التعذّر');
    expect(r.s.pending, isEmpty);

    await r.n.leaveAtDoor(order[0], const []);
    await Future<void>.delayed(Duration.zero);
    expect(r.events.last.message, 'الترك عند الباب يحتاج صورة');
    expect(r.s.pending, isEmpty);

    await r.n.fail(order[0], 'العميل غير متواجد');
    expect(r.morning.current?.id, order[1]);
    await r.n.leaveAtDoor(order[1], const [7, 7]);
    expect(r.morning.current?.id, order[2]);
    await until(() => r.repo.statusOf(order[0]) == 'failed' && r.repo.statusOf(order[1]) == 'delivered');
    expect(r.repo.handoffOf(order[1]), 'door');
    await until(() => r.s.pending.isEmpty);
    expect(r.morning.failed.map((x) => x.id), [order[0]]);
  });

  test('S-7 · الصورةُ الإلزاميّة: التطبيقُ يمنع والخادمُ يمنع', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart();
    await r.n.deliver(order[0]);
    await Future<void>.delayed(Duration.zero);
    expect(r.events.last.message, 'صورة التسليم إلزاميّة في هذا المطعم');
    expect(r.s.pending, isEmpty);
    expect(r.stop(order[0]).isOpen, isTrue);
    await expectLater(
      r.repo.setStatus(order[0], 'delivered'),
      throwsA(isA<DriverActionError>()
          .having((e) => e.kind, 'kind', DriverErrorKind.permanent)
          .having((e) => e.message, 'message', 'صورة التسليم إلزاميّة في هذا المطعم')),
    );

    // مطعمٌ جعلها اختياريّة: يُسلَّم بلا صورة.
    final r2 = Rig(photoRequired: false);
    addTearDown(r2.dispose);
    await r2.signIn();
    final o2 = await r2.loadAndStart();
    await r2.n.deliver(o2[0]);
    await until(() => r2.repo.statusOf(o2[0]) == 'delivered');
  });

  test('S-8 · رفضُ الخادم يُقال بنصّه وتعود المحطّة مفتوحة', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart();
    r.repo.doorAllowed = false; // المطعمُ غيّر إعدادَه والتطبيقُ لم يقرأه بعد
    await r.n.leaveAtDoor(order[0], const [1]);
    expect(r.stop(order[0]).isClosed, isTrue);
    await until(() => r.events.any((e) => e.message == 'الترك عند الباب غير مسموح في هذا المطعم'));
    await until(() => r.s.pending.isEmpty);
    expect(r.stop(order[0]).isOpen, isTrue);
    expect(r.morning.current?.id, order[0]);
    expect(r.stop(order[1]).status, isNot(StopStatus.enroute), reason: 'التابعُ سقط مع أصله');
  });

  test('S-9 · أجِّل واذهب إليها الآن', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart();
    await until(() => r.repo.statusOf(order[0]) == 'out_for_delivery');

    await r.n.deferStop(order[0]);
    expect(r.morning.current?.id, order[1]);
    expect(r.morning.open.last.id, order[0]);
    await until(() => r.repo.statusOf(order[0]) == 'ready' && r.repo.statusOf(order[1]) == 'out_for_delivery');
    expect(r.repo.pickedOf(order[0]), isTrue, reason: 'الكيسُ ما زال معه');

    await r.n.goNow(order[2]);
    expect(r.morning.current?.id, order[2]);
    await until(() => r.repo.statusOf(order[1]) == 'ready' && r.repo.statusOf(order[2]) == 'out_for_delivery');
    expect(r.s.local.pinned, order[2]);

    r.n.recordCall(order[2]);
    r.n.recordCall(order[2]);
    expect(r.s.local.calls[order[2]], 2);
  });

  test('S-10 · الكيسُ غيرُ المحمَّل لا يُرسَل «في الطريق» حتّى «نعم، معي»', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart(load: 1);
    await r.n.deliver(order[0], photo: [1]);
    expect(r.morning.current?.id, order[1]);
    expect(r.stop(order[1]).isLoaded, isFalse);
    expect(r.stop(order[1]).status, isNot(StopStatus.enroute));
    await r.n.markLoaded(order[1]);
    expect(r.stop(order[1]).status, StopStatus.enroute);
    await until(() => r.repo.statusOf(order[1]) == 'out_for_delivery');
  });

  test('S-11 · انقطاع: يبقى الفعلُ ويُعاد، والحالةُ تقول «بلا اتصال»', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final first = r.morning.open.first;
    r.repo.offline = true;
    await r.n.markLoaded(first.id);
    await until(() => r.s.offline, what: 'بلا اتصال');
    expect(r.s.pending.single.attempts, greaterThanOrEqualTo(1));
    expect(r.stop(first.id).isLoaded, isTrue);
    r.repo.offline = false;
    await until(() => r.repo.pickedOf(first.id), what: 'الإعادةُ بعد التباعد', timeout: const Duration(seconds: 8));
    await until(() => !r.s.offline && r.s.pending.isEmpty);
  });

  test('S-12 · الجلسةُ الميّتة ⇒ خروجٌ وطابورٌ فارغ', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    await r.repo.signOut(); // أُبطل الرمزُ من مكانٍ آخر
    await r.n.refresh();
    await until(() => r.s.auth == AuthStatus.signedOut);
    expect(r.events.any((e) => e.error && e.message.contains('جلستك')), isTrue);
    expect(r.s.stops, isEmpty);
  });

  test('S-13 · نهايةُ الفترة: «انتهى» يبقى معروضًا حتّى «وصلتُ المطبخ»', () async {
    final r = Rig(photoRequired: false);
    addTearDown(r.dispose);
    await r.signIn();
    final order = await r.loadAndStart(load: 8);
    for (final id in order) {
      await r.n.deliver(id);
    }
    expect(r.morning.phase, RoutePhase.done);
    expect(r.c.read(currentGroupProvider)?.key, MockDriverRepository.morning);
    r.n.ackGroup(MockDriverRepository.morning);
    expect(r.c.read(currentGroupProvider)?.key, MockDriverRepository.evening);
    await until(() => r.s.pending.isEmpty, timeout: const Duration(seconds: 10));
    expect(r.morning.closedCount, 8);
  });

  test('S-14 · المحادثة والسجلّ', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await r.signIn();
    final s12 = r.s.stops.firstWhere((x) => x.bagNo == 12);
    await r.n.loadMessages(s12.id);
    expect(r.s.messages[s12.id], hasLength(2));
    expect(await r.n.sendMessage(s12.id, 'وصلت، أنا عند الباب'), isTrue);
    expect(r.s.messages[s12.id]!.last.outgoing, isTrue);
    expect(await r.n.sendMessage(s12.id, '  '), isFalse);

    r.n.setOpenChat(s12.id);
    r.repo.simulateCustomerMessage(s12.id, 'تمام');
    await until(() => r.s.messages[s12.id]!.length == 4);
    r.n.setOpenChat(null);

    await r.n.loadHistory();
    expect(r.s.historyLoaded, isTrue);
    expect(r.s.history.length, greaterThan(25));
  });
}
