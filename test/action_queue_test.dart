// ============================================================================
// طابورُ الأفعال — ما يضمن ألّا يضيع تسليمٌ ولا يُرسَل ما تراجع عنه المندوب.
// الساعةُ مزيّفة والمؤقّتاتُ مطفأة: الاختبارُ يقدّم الوقتَ وينادي `pump` بنفسه.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/data/action_queue.dart';
import 'package:moaatmat_driver/data/driver_repository.dart';

class Harness {
  Harness({QueueStore? store}) : store = store ?? MemoryQueueStore() {
    queue = ActionQueue(
      store: this.store,
      autoSchedule: false,
      run: (a, photo) async {
        sent.add('${a.deliveryId}:${a.action}${photo == null ? '' : '+${photo.length}'}');
        final f = failWith.remove('${a.deliveryId}:${a.action}');
        if (f != null) throw f;
      },
      onCommitted: (a) => committed.add(a.key),
      onPermanent: (a, m) => permanent.add(m),
      onTransient: (a, m) => transient.add(m),
      onSession: (e) => sessions++,
    );
  }

  final QueueStore store;
  late final ActionQueue queue;
  final sent = <String>[];
  final committed = <String>[];
  final permanent = <String>[];
  final transient = <String>[];
  final failWith = <String, DriverActionError>{};
  int sessions = 0;
}

late DateTime now;
void advance(Duration d) => now = now.add(d);

void main() {
  setUp(() {
    now = DateTime(2026, 10, 2, 7);
    QueueClock.now = () => now;
  });

  test('Q-1 · لا يُرسَل قبل انتهاء المهلة، ويُرسَل بعدها', () async {
    final h = Harness();
    final a = await h.queue.enqueue('d1', 'delivered', grace: const Duration(seconds: 10), photo: [1, 2, 3]);
    expect(a.undoable, isTrue);
    await h.queue.pump();
    expect(h.sent, isEmpty);
    advance(const Duration(seconds: 9));
    await h.queue.pump();
    expect(h.sent, isEmpty);
    advance(const Duration(seconds: 1));
    expect(a.undoable, isFalse);
    await h.queue.pump();
    expect(h.sent, ['d1:delivered+3']);
    expect(h.queue.items, isEmpty);
    expect(h.committed, [a.key]);
  });

  test('Q-2 · التراجعُ يُسقط الفعلَ وتوابعَه بأيّ عمق — وبعد المهلة لا تراجع', () async {
    final h = Harness();
    final a = await h.queue.enqueue('d1', 'delivered', grace: const Duration(seconds: 10));
    final next = await h.queue.enqueue('d2', 'enroute', parentKey: a.key, commitAt: a.commitAt);
    await h.queue.enqueue('d3', 'enroute', parentKey: next.key, commitAt: a.commitAt);
    final other = await h.queue.enqueue('d4', 'picked', grace: const Duration(seconds: 4));
    expect(h.queue.undo(a.key), isTrue);
    expect([for (final x in h.queue.items) x.key], [other.key]);
    advance(const Duration(seconds: 30));
    await h.queue.pump();
    expect(h.sent, ['d4:picked']);
    expect(h.queue.undo(other.key), isFalse, reason: 'أُرسل — لا تراجع');

    final lateOne = await h.queue.enqueue('d5', 'failed', reason: 'x', grace: const Duration(seconds: 10));
    advance(const Duration(seconds: 10));
    expect(h.queue.undo(lateOne.key), isFalse, reason: 'انتهت المهلة');
  });

  test('Q-3 · التابعُ ينتظر أصلَه حتّى إن حان وقتُه', () async {
    final h = Harness();
    final a = await h.queue.enqueue('d1', 'delivered', grace: const Duration(seconds: 10));
    await h.queue.enqueue('d2', 'enroute', parentKey: a.key, commitAt: now);
    await h.queue.pump();
    expect(h.sent, isEmpty);
    advance(const Duration(seconds: 10));
    await h.queue.pump();
    expect(h.sent, ['d1:delivered', 'd2:enroute']);
  });

  test('Q-4 · FIFO لكلّ توصيلة: لا يسبق فعلٌ لاحقٌ أسبقَه، والتوصيلاتُ الأخرى لا تنتظر', () async {
    final h = Harness();
    await h.queue.enqueue('d1', 'picked', grace: const Duration(seconds: 4));
    await h.queue.enqueue('d1', 'enroute'); // حان وقتُه — لكنّه خلف «حُمّل»
    await h.queue.enqueue('d2', 'enroute');
    await h.queue.pump();
    expect(h.sent, ['d2:enroute']);
    advance(const Duration(seconds: 4));
    await h.queue.pump();
    expect(h.sent, ['d2:enroute', 'd1:picked', 'd1:enroute']);
  });

  test('Q-5 · العابرُ يُعاد بتباعدٍ لا يتجاوز ٦٠ ث، ويحجب ما بعده لتوصيلته', () async {
    final h = Harness();
    h.failWith['d1:delivered'] = const DriverActionError.transient();
    await h.queue.enqueue('d1', 'delivered');
    await h.queue.enqueue('d1', 'failed', reason: 'x');
    await h.queue.pump();
    expect(h.sent, ['d1:delivered']);
    expect(h.queue.items.first.attempts, 1);
    expect(h.queue.items.first.lastError, isNotNull);
    expect(h.transient, hasLength(1));
    await h.queue.pump();
    expect(h.sent, hasLength(1), reason: 'ينتظر تباعدَه');
    advance(ActionQueue.backoff(1));
    await h.queue.pump();
    expect(h.sent, ['d1:delivered', 'd1:delivered', 'd1:failed']);
    expect(ActionQueue.backoff(10), const Duration(seconds: 60));
    expect(ActionQueue.backoff(1), const Duration(seconds: 2));
  });

  test('Q-6 · الدائمُ يُسقَط مع توابعه ويُقال سببُه، وما بعده يمضي', () async {
    final h = Harness();
    h.failWith['d1:delivered'] = const DriverActionError.permanent('صورة التسليم إلزاميّة في هذا المطعم');
    final a = await h.queue.enqueue('d1', 'delivered');
    await h.queue.enqueue('d2', 'enroute', parentKey: a.key, commitAt: a.commitAt);
    await h.queue.enqueue('d3', 'picked');
    await h.queue.pump();
    expect(h.permanent, ['صورة التسليم إلزاميّة في هذا المطعم']);
    expect(h.sent, ['d1:delivered', 'd3:picked']);
    expect(h.queue.items, isEmpty);
  });

  test('Q-7 · الجلسةُ الميّتة توقف الطابورَ ولا تُسقط شيئًا', () async {
    final h = Harness();
    h.failWith['d1:picked'] = const DriverActionError.session();
    await h.queue.enqueue('d1', 'picked');
    await h.queue.enqueue('d2', 'picked');
    await h.queue.pump();
    expect(h.sessions, 1);
    expect(h.sent, ['d1:picked']);
    expect(h.queue.items, hasLength(2));
    await h.queue.clear();
    expect(h.queue.items, isEmpty);
  });

  test('Q-8 · الحفظ: طابورٌ جديدٌ على المخزن نفسه يستعيد الأفعالَ وصورَها', () async {
    final store = MemoryQueueStore();
    final h1 = Harness(store: store);
    final a = await h1.queue.enqueue('d1', 'delivered_door', grace: const Duration(seconds: 10), photo: [9, 8, 7, 6]);
    await h1.queue.enqueue('d2', 'failed', reason: 'العنوان غير صحيح', parentKey: a.key, commitAt: a.commitAt);
    h1.queue.dispose();

    final h2 = Harness(store: store);
    await h2.queue.load();
    expect(h2.queue.items, hasLength(2));
    final r = h2.queue.items.first;
    expect(r.key, a.key);
    expect(r.action, 'delivered_door');
    expect(r.commitAt, a.commitAt);
    expect(h2.queue.items.last.reason, 'العنوان غير صحيح');
    expect(h2.queue.items.last.parentKey, a.key);
    expect(await store.loadPhoto(r.photoRef!), [9, 8, 7, 6]);

    advance(const Duration(seconds: 10));
    await h2.queue.pump();
    expect(h2.sent, ['d1:delivered_door+4', 'd2:failed']);
    expect(await store.loadPhoto(r.photoRef!), isNull, reason: 'الصورةُ تُمحى بعد الإرسال');
    // والطابورُ الفارغ محفوظٌ فارغًا.
    final h3 = Harness(store: store);
    await h3.queue.load();
    expect(h3.queue.items, isEmpty);
  });

  test('Q-9 · طابورٌ تالفٌ في المخزن لا يُسقط التطبيق', () async {
    final store = MemoryQueueStore()..data = '{not json';
    final h = Harness(store: store);
    await h.queue.load();
    expect(h.queue.items, isEmpty);
  });

  test('Q-10 · صورةٌ ضاعت من المخزن ⇒ رفضٌ دائمٌ بسببٍ ظاهر، لا تسليمٌ بلا إثبات', () async {
    final store = MemoryQueueStore();
    final h = Harness(store: store);
    final a = await h.queue.enqueue('d1', 'delivered', photo: [1]);
    store.photos.clear();
    await h.queue.pump();
    expect(h.sent, isEmpty);
    expect(h.permanent.single, contains('صورة'));
    expect(h.queue.items.where((x) => x.key == a.key), isEmpty);
  });

  test('Q-11 · flush يُنهي المهلَ ويرسل الآن', () async {
    final h = Harness();
    await h.queue.enqueue('d1', 'delivered', grace: const Duration(seconds: 10));
    await h.queue.flush();
    expect(h.sent, ['d1:delivered']);
  });

  test('Q-F · «اخرج» يرسل حتّى ما ينتظر تباعدَه — ولا يتخطّاه فيمحوه الخروج', () async {
    final h = Harness();
    h.failWith['d1:delivered'] = const DriverActionError.transient();
    await h.queue.enqueue('d1', 'delivered', photo: [1]);
    await h.queue.pump();
    expect(h.queue.items.single.nextTryAt, isNotNull, reason: 'فشل مرّةً فينتظر');
    await h.queue.flush(); // الشبكةُ عادت قبل انتهاء التباعد
    expect(h.sent, ['d1:delivered+1', 'd1:delivered+1']);
    expect(h.queue.items, isEmpty);
  });

  test('Q-P · «أوقف» لا يمحو، و«ابدأ» يستأنف (جلسةٌ ماتت ثمّ عاد صاحبُها)', () async {
    final h = Harness();
    await h.queue.enqueue('d1', 'picked');
    h.queue.pause();
    await h.queue.pump();
    expect(h.sent, isEmpty);
    expect(h.queue.items, hasLength(1));
    h.queue.kick();
    await h.queue.pump();
    expect(h.sent, ['d1:picked']);
    final s = MemoryQueueStore();
    expect(await s.readOwner(), isNull);
    await s.writeOwner('drv-1');
    expect(await s.readOwner(), 'drv-1');
  });
}
